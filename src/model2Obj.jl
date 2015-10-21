module Model2Obj
"""
Module that takes a 3d model and write it on
obj files
"""

require(string(Pkg.dir("ImagesToLARModel/src"), "/larUtils.jl"))

import LARUtils

using Logging

export writeToObj, mergeObj, computeModel


function lessThanVertices(v1, v2)
  """
  Utility function for comparing vertices coordinates
  """
  
  if v1[1] == v2[2]
    if v1[2] == v2[2]
      return v1[3] < v2[3]
    end
    return v1[2] < v2[2]
  end
  return v1[1] < v2[2]
end

function removeDoubleVerticesAndFaces(V, FV, facesOffset)
  """
  Removes double vertices and faces from a LAR model

  V: Array containing all vertices
  FV: Array containing all faces
  facesOffset: offset for faces indices
  """

  newV, indices = removeDoubleVertices(V)
  reindexedFaces = reindexVerticesInFaces(FV, indices, facesOffset)
  newFV = unique(FV)

  return newV, newFV

end

function removeDoubleVertices(V)
  """
  Remove double vertices from a LAR model

  V: Array containing all vertices of the model
  """

  # Sort the vertices list and returns the ordered indices
  orderedIndices = sortperm(V, lt = lessThanVertices, alg=MergeSort)

  orderedVerticesAndIndices = collect(zip(sort(V, lt = lessThanVertices),
                                          orderedIndices))
  newVertices = Array(Array{Int}, 0)
  indices = zeros(Int, length(V))
  prevv = Nothing
  i = 1
  for (v, ind) in orderedVerticesAndIndices
    if v == prevv
      indices[ind] = i - 1
    else
      push!(newVertices, v)
      indices[ind] = i
      i += 1
      prevv = v
    end
  end
  return newVertices, indices
end

function reindexVerticesInFaces(FV, indices, offset)
  """
  Reindex vertices indexes in faces array

  FV: Faces array of the LAR model
  indices: new Indices for faces
  offset: offset for faces indices
  """

  for f in FV
    for i in 1: length(f)
      f[i] = indices[f[i] - offset] + offset
    end
  end
  return FV
end

function computeModel(imageDx, imageDy, imageDz,
                      xStart, yStart, zStart,
                      facesOffset, objectBoundaryChain)
  """
  Takes the boundary chain of a part of the entire model
  and returns a LAR model

  imageDx, imageDy, imageDz: Boundary dimensions
  xStart, yStart, zStart: Offset of this part of the model
  facesOffset: Offset for the faces
  objectBoundaryChain: Sparse csc matrix containing the cells
  """

  V, bases = LARUtils.getBases(imageDx, imageDy, imageDz)
  FV = bases[3]

  V_model = Array(Array{Int}, 0)
  FV_model = Array(Array{Int}, 0)

  vertex_count = 1

  #b2cells = Lar2Julia.cscChainToCellList(objectBoundaryChain)
  # Get all cells (independently from orientation)
  b2cells = findn(objectBoundaryChain)[1]

  debug("b2cells = ", b2cells)

  for f in b2cells
    old_vertex_count = vertex_count
    for vtx in FV[f]
      push!(V_model, [convert(Int, V[vtx + 1][1] + xStart),
                    convert(Int64, V[vtx + 1][2] + yStart),
                    convert(Int64, V[vtx + 1][3] + zStart)])
      vertex_count += 1
    end

    push!(FV_model, [old_vertex_count + facesOffset, old_vertex_count + 1 + facesOffset, old_vertex_count + 3 + facesOffset])
    push!(FV_model, [old_vertex_count + facesOffset, old_vertex_count + 3 + facesOffset, old_vertex_count + 2 + facesOffset])
  end
  
  # Removing double vertices
  return removeDoubleVerticesAndFaces(V_model, FV_model, facesOffset)

end

function writeToObj(V, FV, outputFilename)
  """
  Take a LAR model and write it on obj file

  V: array containing vertices coordinates
  FV: array containing faces
  outputFilename: prefix for the output files
  """
  
  outputVtx = string(outputFilename, "_vtx.stl")
  outputFaces = string(outputFilename, "_faces.stl")

  fileVertex = open(outputVtx, "w")
  fileFaces = open(outputFaces, "w")

  for v in V
    write(fileVertex, "v ")
    write(fileVertex, string(v[1], " "))
    write(fileVertex, string(v[2], " "))
    write(fileVertex, string(v[3], "\n"))
  end

  for f in FV

    write(fileFaces, "f ")
    write(fileFaces, string(f[1], " "))
    write(fileFaces, string(f[2], " "))
    write(fileFaces, string(f[3], "\n"))
  end

  close(fileVertex)
  close(fileFaces)

end

function mergeObj(modelDirectory)
  """
  Merge stl files in a single obj file

  modelDirectory: directory containing models
  """

  files = readdir(modelDirectory)
  vertices_files = files[find(s -> contains(s,string("_vtx.stl")), files)]
  faces_files = files[find(s -> contains(s,string("_faces.stl")), files)]
  obj_file = open(string(modelDirectory,"/","model.obj"),"w") # Output file

  vertices_counts = Array(Int64, length(vertices_files))
  number_of_vertices = 0
  for i in 1:length(vertices_files)
    vtx_file = vertices_files[i]
    f = open(string(modelDirectory, "/", vtx_file))
    debug("Opening ", vtx_file)

    # Writing vertices on the obj file
    for ln in eachline(f)
      write(obj_file, ln)
      number_of_vertices += 1
    end
    # Saving number of vertices
    vertices_counts[i] = number_of_vertices
    close(f)
  end

  for i in 1 : length(faces_files)
    faces_file = faces_files[i]
    f = open(string(modelDirectory, "/", faces_file))
    debug("Opening ", faces_file)
    for ln in eachline(f)
      splitted = split(ln)
      write(obj_file, "f ")
      if i > 1
        write(obj_file, string(parse(splitted[2]) + vertices_counts[i - 1], " "))
        write(obj_file, string(parse(splitted[3]) + vertices_counts[i - 1], " "))
        write(obj_file, string(parse(splitted[4]) + vertices_counts[i - 1]))
      else
        write(obj_file, string(splitted[2], " "))
        write(obj_file, string(splitted[3], " "))
        write(obj_file, splitted[4])
      end
      write(obj_file, "\n")
    end
    close(f)
  end
  close(obj_file)

  # Removing all tmp files
  for vtx_file in vertices_files
    rm(string(modelDirectory, "/", vtx_file))
  end

  for fcs_file in faces_files
    rm(string(modelDirectory, "/", fcs_file))
  end

end
end
