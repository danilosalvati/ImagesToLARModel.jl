module Lar2Julia

import JSON

using Logging

export larBoundaryChain, cscChainToCellList, relationshipListToCSC 

function larBoundaryChain(cscBoundaryMat, brcCellList)
  """
  Compute boundary chains
  """

  # Computing boundary chains
  n = size(cscBoundaryMat)[1]
  m = size(cscBoundaryMat)[2]

  debug("Boundary matrix size: ", n, "\t", m)

  data = ones(Int64, length(brcCellList))

  i = Array(Int64, length(brcCellList))
  for k in 1:length(brcCellList)
    i[k] = brcCellList[k] + 1
  end

  j = ones(Int64, length(brcCellList))

  debug("cscChain rows length: ", length(i))
  debug("cscChain columns length: ", length(j))
  debug("cscChain data length: ", length(brcCellList))

  debug("rows ", i)
  debug("columns ", j)
  debug("data ", data)

  cscChain = sparse(i, j, data, m, 1)
  cscmat = cscBoundaryMat * cscChain
  out = cscBinFilter(cscmat)
  return out
end

function cscBinFilter(CSCm)
  k = 1
  data = nonzeros(CSCm)
  sgArray = copysign(1, data)

  while k <= nnz(CSCm)
    if data[k] % 2 == 1 || data[k] % 2 == -1
      data[k] = 1 * sgArray[k]
    else
      data[k] = 0
    end
    k += 1
  end

  return CSCm
end 

function cscChainToCellList(CSCm)
  """
  Get a csc containing a chain and returns
  the cell list of the "+1" oriented faces
  """
  data = nonzeros(CSCm)
  # Now I need to remove zero element (problem with Julia nonzeros)
  nonzeroData = Array(Int64, 0)
  for n in data
    if n != 0
      push!(nonzeroData, n)
    end
  end

  cellList = Array(Int64,0)
  for (k, theRow) in enumerate(findn(CSCm)[1])
    if nonzeroData[k] == 1
      push!(cellList, theRow)
    end
  end
  return cellList
end 

function relationshipListToCSC(larRelation)
  """
  Get a LAR relationship
  and convert it into a CSC matrix
  """

  # Build I and J arrays for creation of
  # sparse matrix
  data = Array(Int, 0)
  I = Array(Int, 0)
  J = Array(Int, 0)
  for (k,row) in enumerate(larRelation)
    for col in row
      push!(I, k)
      push!(J, col)
      push!(data, 1)
    end
  end

  return sparse(I, J, data)
end 

function convexCombination(vectors)
  """
  Compute the convex combination of an
  array of vectors

  vectors: An array of vectors
  """
  # Computing sum of all vectors
  sum = [0.0, 0.0, 0.0]
  for v in vectors
    sum += v
  end
  return sum/length(vectors)
end 

function cscTranspose(CSCm)
  """
  Compute the transpose matrix of a
  sparse CSC matrix
  """
  rows, columns = findn(CSCm)
  data = nonzeros(CSCm)
  return sparse(columns, rows, data, size(CSCm)[2], size(CSCm)[1])
end 

function cscBoundaryFilter(CSCm)
  """
  Matrix filtering to produce the boundary
  matrix. It returns only max values for
  every row

  CSCm: a matrix in the CSC format
  """

  # Now I iterate on all rows of the matrix
  # saving only the max values on the row in a
  # new sparse matrix
  rows = Array(Int, 0)
  columns = Array(Int, 0)
  data = Array(Int, 0)
  
  # I need to compute the transposed matrix
  # for improving performances. In fact Julia
  # use only column-stored arrays so it is
  # inefficient to iterate over rows
  transCSCm = cscTranspose(CSCm)

  for k in 1 : size(transCSCm)[2]
    matrixColumn = transCSCm[:, k]
    maxColumnValue = maximum(matrixColumn)
    rowIndices, _ = findn(matrixColumn)
    for rowIndex in rowIndices
      if transCSCm[rowIndex, k] == maxColumnValue
        push!(rows, k)
        push!(columns, rowIndex)
        push!(data, 1)
      end
    end
  end
  return sparse(rows, columns, data, size(CSCm)[1], size(CSCm)[2])
end 

function boundary(cells, facets)
  """
  Take the usual LAR representation of d-cells
  and (d-1)-facets and returns the
  boundary operator in csc format

  cell, facets: d-cells and (d-1)-facets in BRC format
  """
  cscCV = relationshipListToCSC(cells)
  cscFV = relationshipListToCSC(facets)
  cscFC = cscFV * cscTranspose(cscCV)
  return cscBoundaryFilter(cscFC)
end 

function larIncidence(cells, facets)
  """
  The incidence operator between cells
  and facets of a LAR model

  cells, facets: cells and facets BRC representation
  of a LAR model
  """
  # The cell-face incidence operator
  cscCellFacet = boundary(facets, cells)
  larCellFacet = Array(Array{Int}, length(cells))
  rows, columns = findn(cscCellFacet)
  zipped = zip(rows, columns, nonzeros(cscCellFacet))
  for (i, j, val) in zipped
    if val == 1
      if(!isdefined(larCellFacet, i))
        larCellFacet[i] = []
      end
      append!(larCellFacet[i], collect(j))
    end
  end
  return larCellFacet
end

function incidenceChain(bases)
  """
  Compute the full stack of BRC incidence matrices of
  a LAR representation for a cellular complex, starting
  from its list of bases, i.e. from [VV,EV,FV,CV,...]

  bases: bases of a LAR cellular complex
  """
  pairsOfBases = zip(bases[2 : end], bases[1 : end - 1])
  relations = [larIncidence(cells, facets) for (cells,facets) in pairsOfBases]
  return reverse(relations)
end 

function signedCellularBoundary(V, bases)
  """
  Compute the signed cellular boundary
  for polytopal complexes

  V: the array of vertices
  bases: the bases of a LAR model
  """
  
  # First of all I need to convert LAR bases in Julia
  # 1-based indexing
  reindexedBases = deepcopy(bases)
  for i in 1 : length(reindexedBases)
    for j in 1 : length(reindexedBases[i])
      for z in 1 : length(reindexedBases[i][j])
        reindexedBases[i][j][z] += 1
      end
    end
  end

  cscBoundary = boundary(reindexedBases[end], reindexedBases[end - 1])
  rows, columns = findn(cscBoundary)
  pairs = map(((x,y) -> return[x, y]), rows, columns)
  dim = length(reindexedBases) - 1
  signs = Array(Int, 0)
  chain = incidenceChain(reindexedBases)
  for pair in pairs
    flag = reverse(pair)
    for k in 1 : dim - 1
      cell = flag[end]
      append!(flag, collect(chain[k + 1][cell][2]))
    end
        
    verts = [convexCombination([V[v] for v in reindexedBases[dim - k + 1][flag[k + 1]]])
             for k in 0 : dim]
    flagMat = Array(Float64, dim + 1, dim + 1)
    
    # verts is useless and can be integrated into this for!!!
    for j in 1 : dim
      for i in 1 : dim + 1
        flagMat[i, j] = verts[i][j]
        flagMat[i, dim + 1] = 1
      end
    end
    
    flagSign = sign(det(flagMat))
    push!(signs, flagSign)
  end
  transposedPairs = transpose(pairs)
  return sparse(map(((x)->return x[1]), pairs), map(((x)->return x[2]), pairs), signs)
end  
end
