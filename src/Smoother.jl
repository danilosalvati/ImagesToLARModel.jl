module Smoother
import Lar2Julia
export smoothModel

function adjVerts(V, FV)
  """
  Compute the adjacency graph of vertices
  of a LAR model

  V, FV: LAR model

  Returns the list of indices of vertices adjacent
  to a vertex
  """
  EV = Lar2Julia.larSimplexFacets(FV)
  VV = Array(Array{Int},length(V))  
  for edge in EV
    if !isdefined(VV, edge[1])
      VV[edge[1]] = []
    end
    
    if !isdefined(VV, edge[2])
      VV[edge[2]] = []
    end
    
    push!(VV[edge[1]], edge[2])
    push!(VV[edge[2]], edge[1])
  end
  return VV
end 

function smoothModel(V, FV)
  """
  Execute a Laplacian smoothing on a LAR model returning
  the new smoothed model

  V, FV: LAR model
  """

  VV = adjVerts(V, FV)
  newV = Array(Array{Float64},0)
  for i in 1:length(VV)
    adjs = VV[i]
    # Get all coordinates for adjacent vertices
    coords = Array(Array{Float64}, 0)
    for v in adjs
      push!(coords, V[v])
    end    
    push!(newV, Lar2Julia.convexCombination(coords))
  end
  return newV, FV
end 
end
