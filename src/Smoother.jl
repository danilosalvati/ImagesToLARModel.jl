module Smoother

function adjVerts(V, FV)
  """
  Compute the adjacency graph of vertices
  of a LAR model

  V, FV: LAR model

  Returns the list of indices of vertices adjacent
  to a vertex
  """
  VV = Array{Int}[]
  for i in 1:length(V)
    row = Array(Int, 0)
    for face in FV
      if i in face
        for v in face
          push!(row, v)
        end
      end
    end
    if length(row) == 0
      push!(row, i)
    end
    push!(VV, collect(unique(row)))
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
