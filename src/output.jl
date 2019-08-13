"""
    Output(prob, filename, fieldtuples...)

Define output for `prob` with fields and functions that calculate
the output in the list of tuples `fieldtuples = (fldname, func)...`.
"""
struct Output
  prob::Problem
  path::String
  fields::Dict{Symbol,Function}
end

withoutjld2(path) = (length(path)>4 && path[end-4:end] == ".jld2") ? path[1:end-5] : path

"""
    uniquepath(path)

Returns `path` with a number appended if `isfile(path)`, incremented until `path` does not exist.
"""
function uniquepath(path)
  n = 1
  if isfile(path)
    path = withoutjld2(path) * "_$n.jld2"
  end
  while isfile(path)
    n += 1
    path = withoutjld2(path)[1:end-length("_$(n-1)")] * "_$n.jld2"
  end
  path
end
    
function Output(prob, path, fields::Dict{Symbol,Function})
  truepath = uniquepath(withoutjld2(path)*".jld2") # ensure path ends in ".jld2"
  saveproblem(prob, truepath)
  Output(prob, filename, fields)
end

Output(prob, path, fields...) = Output(prob, path, Dict{Symbol,Function}([fields...]))
Output(prob, path, field::Tuple{Symbol,T}) where T = Output(prob, path, Dict{Symbol,Function}([field]))

getindex(out::Output, key) = out.fields[key](out.prob)

"""
    saveoutput(out)

Save the fields in `out.fields` to `out.path`.
"""
function saveoutput(out)
  groupname = "snapshots"
  jldopen(out.path, "a+") do path
    path["$groupname/t/$(out.prob.clock.step)"] = out.prob.clock.t
    for fieldname in keys(out.fields)
      path["$groupname/$fieldname/$(out.prob.clock.step)"] = Array(out[fieldname])
    end
  end
  nothing
end

"""
    savefields(file, field)

Saves some parameters of `prob.field`.
"""
function savefields(file::JLD2.JLDFile{JLD2.MmapIO}, grid::TwoDGrid)
  for field in [:nx, :ny, :Lx, :Ly]
    file["grid/$field"] = getfield(grid, field)
  end
  for field in [:x, :y]
    file["grid/$field"] = Array(getfield(grid, field))
  end
  nothing
end

function savefields(file::JLD2.JLDFile{JLD2.MmapIO}, grid::OneDGrid)
  for field in [:nx, :Lx]
    file["grid/$field"] = getfield(grid, field)
  end
  for field in [:x]
    file["grid/$field"] = Array(getfield(grid, field))
  end
  nothing
end

function savefields(file::JLD2.JLDFile{JLD2.MmapIO}, params::AbstractParams)
  for name in fieldnames(typeof(params))
    field = getfield(params, name)
    if !(typeof(field) <: Function)
      if HAVE_CUDA && typeof(field) <: CuArray
        file["params/$name"] = Array(field)
      else
        file["params/$name"] = field
      end
    end
  end
  nothing
end

function savefields(file::JLD2.JLDFile{JLD2.MmapIO}, clock::Clock)
  file["clock/dt"] = clock.dt
  nothing
end

function savefields(file::JLD2.JLDFile{JLD2.MmapIO}, eqn::Equation)
  file["eqn/L"] = Array(eqn.L)  # convert to CPU Arrays before saving
  file["eqn/dims"] = eqn.dims
  file["eqn/T"] = eqn.T
  nothing
end

"""
    saveproblem(prob, filename)

Save certain aspects of a problem.
"""
function saveproblem(prob, filename)
  file = jldopen(filename, "a+")
  for field in [:eqn, :clock, :grid, :params]
    savefields(file, getfield(prob, field))
  end
  close(file)
  nothing
end

saveproblem(out::Output) = saveproblem(out.prob, out.path)

"""
    savediagnostic(diag, diagname)

Save diagnostics in `diag` to file, labeled by `diagname`.
"""
function savediagnostic(diag, diagname, filename)
  jldopen(filename, "a+") do file
    file["diags/$diagname/steps"] = diag.steps
    file["diags/$diagname/t"] = diag.t
    file["diags/$diagname/data"] = diag.data
  end
  nothing
end
