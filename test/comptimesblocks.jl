#!/usr/bin/env julia

using Cumulants
using SymmetricTensors
using CumulantsUpdates
using JLD
using ArgParse


function comptime(X::Matrix{Float64}, Xup::Matrix{Float64}, m::Int, b::Int)
  t = time_ns()
  _, X = cumulantsupdat(X, Xup, m, b)
  Float64(time_ns()-t)/1.0e9, X
end

function precomp(m::Int)
  X = randn(15, 10)
  cumulantscache(X[1:10,:], m, 4)
  cumulantsupdat(X[1:10,:], X[10:15,:], m, 4)
end

function savect(u::Vector{Int}, n::Int, m::Int, p::Int)
  maxb = round(Int, sqrt(n))+2
  comptimes = zeros(maxb-1, length(u))
  println("max block size = ", maxb)
  precomp(m)
  for b in 2:maxb
    X = randn(maximum(u)+10, n)
    println("bloks size = ", b)
    cumulantscache(X, m, b)
    for k in 1:length(u)
      Xup = randn(u[k], n)
      comptimes[b-1, k], X = comptime(X, Xup, m, b)
      println("u = ", u[k])
    end
  end
  filename = replace("res/$(m)_$(u)_$(n)_$(p)_nblocks.jld", "[", "")
  filename = replace(filename, "]", "")
  filename = replace(filename, " ", "")
  compt = Dict{String, Any}("cumulants"=> comptimes)
  push!(compt, "t" => u)
  push!(compt, "n" => n)
  push!(compt, "m" => m)
  push!(compt, "x" => "block size")
  push!(compt, "block size" => [collect(2:maxb)...])
  push!(compt, "functions" => [["cumulants"]])
  save(filename, compt)
end


function main(args)
  s = ArgParseSettings("description")
  @add_arg_table s begin
      "--order", "-m"
        help = "m, the order of cumulant, ndims of cumulant's tensor"
        default = 4
        arg_type = Int
      "--nvar", "-n"
        default = 48
        help = "n, numbers of marginal variables"
        arg_type = Int
      "--tup", "-u"
        help = "u, numbers of data updates"
        nargs = '*'
        default = [10000, 20000]
        arg_type = Int
      "--nprocs", "-p"
        help = "number of processes"
        default = 3
        arg_type = Int
    end
  parsed_args = parse_args(s)
  m = parsed_args["order"]
  n = parsed_args["nvar"]
  u = parsed_args["tup"]
  p = parsed_args["nprocs"]
  if p > 1
    addprocs(p)
    eval(Expr(:toplevel, :(@everywhere using CumulantsUpdates)))
  end
  println("number of workers = ", nworkers())
  savect(u, n, m, p)
end

main(ARGS)
