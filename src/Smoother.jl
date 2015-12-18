module Smoother
export smoothModel

function adjVerts(V, FV)
  """
  Compute the adjacency graph of vertices
  of a LAR model

  V, FV: LAR model

  Returns the list of indices of vertices adjacent
  to a vertex
  """
  VV = Array(Array{Int},length(V))
  for i in 1: length(FV)
    for v in FV[i]
      if(!isdefined(VV,v))
        # Adding a new array for this vertex
        VV[v] = Array{Int}[]
      end
      push!(VV[v], FV[i][1], FV[i][2], FV[i][3])
      VV[v] = unique(VV[v])
    end
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
  V_temp = Array(Array{Float64},0)

  for i in 1:length(VV)
    adjs = VV[i]
    # Get all coordinates for adjacent vertices
    coords = Array(Array{Float64}, 0)
    for v in adjs
      push!(coords, V[v])
    end

    # Computing sum of all vectors
    sum = [0.0, 0.0, 0.0]
    for v in coords
      sum += v
    end

    # Computing convex combination of vertices
    push!(newV, sum/length(adjs))

  end

  return newV, FV
end 
end
