module Model2Obj
"""
Module that takes a 3d model and write it on
obj files
"""

require(string(Pkg.dir("ImagesToLARModel/src"), "/larUtils.jl"))

import LARUtils

using Logging

export writeToObj, mergeObj

function writeToObj(imageDx, imageDy, imageDz,
                    xStart, yStart, zStart,
                    objectBoundaryChain, outputFilename)
  """
  Takes the boundary chain of a part of the model
  and writes it on stl files
  """
  V, bases = LARUtils.getBases(imageDx, imageDy, imageDz)
  FV = bases[3]

  outputVtx = string(outputFilename, "_vtx.stl")
  outputFaces = string(outputFilename, "_faces.stl")

  fileVertex = open(outputVtx, "w")
  fileFaces = open(outputFaces, "w")

  vertex_count = 1
  count = 0

  #b2cells = Lar2Julia.cscChainToCellList(objectBoundaryChain)
  # Get all cells (independently from orientation)
  b2cells = findn(objectBoundaryChain)[1]

  debug("b2cells = ", b2cells)

  for f in b2cells
    old_vertex_count = vertex_count
    for vtx in FV[f]
      write(fileVertex, "v ")
      write(fileVertex, string(convert(Int64, V[vtx + 1][1] + xStart)))
      write(fileVertex, " ")
      write(fileVertex, string(convert(Int64, V[vtx + 1][2] + yStart)))
      write(fileVertex, " ")
      write(fileVertex, string(convert(Int64, V[vtx + 1][3] + zStart)))
      write(fileVertex, "\n")
      vertex_count += 1
    end

    write(fileFaces, "f ")
    write(fileFaces, string(old_vertex_count))
    write(fileFaces, " ")
    write(fileFaces, string(old_vertex_count + 1))
    write(fileFaces, " ")
    write(fileFaces, string(old_vertex_count + 3))
    write(fileFaces, "\n")

    write(fileFaces, "f ")
    write(fileFaces, string(old_vertex_count))
    write(fileFaces, " ")
    write(fileFaces, string(old_vertex_count + 3))
    write(fileFaces, " ")
    write(fileFaces, string(old_vertex_count + 2))
    write(fileFaces, "\n")

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
