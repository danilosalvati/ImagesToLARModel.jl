module GenerateBorderMatrix
"""
Module for generation of the boundary matrix
"""

type MatrixObject
  ROWCOUNT
  COLCOUNT
  ROW
  COL
  DATA
end


export computeOriented3Border, writeBorder, getOriented3BorderPath

require("larUtils.jl")

import LARUtils
using PyCall

import JSON

@pyimport sys
unshift!(PyVector(pyimport("sys")["path"]), "") # Search for python modules in folder
# Search for python modules in package folder
unshift!(PyVector(pyimport("sys")["path"]), Pkg.dir("ImagesToLARModel/src"))
@pyimport larcc # Importing larcc from local folder

# Compute the 3-border operator
function computeOriented3Border(nx, ny, nz)
  """
  Compute the 3-border matrix using a modified
  version of larcc
  """
  V, bases = LARUtils.getBases(nx, ny, nz)
  boundaryMat = larcc.signedCellularBoundary(V, bases)
  return boundaryMat

end

function writeBorder(boundaryMatrix, outputFile)
  """
  Write 3-border matrix on json file

  boundaryMatrix: matrix to write on file
  outputFile: path of the outputFile
  """

  rowcount = boundaryMatrix[:shape][1]
  colcount = boundaryMatrix[:shape][2]

  row = boundaryMatrix[:indptr]
  col = boundaryMatrix[:indices]
  data = boundaryMatrix[:data]

  # Writing informations on file
  outfile = open(outputFile, "w")

  matrixObj = MatrixObject(rowcount, colcount, row, col, data)
  JSON.print(outfile, matrixObj)
  close(outfile)

end

function getOriented3BorderPath(borderPath, nx, ny, nz)
  """
  Try reading 3-border matrix from file. If it fails matrix
  is computed and saved on disk in JSON format

  borderPath: path of border directory
  nx, ny, nz: image dimensions
  """

  filename = string(borderPath,"/border_", nx, "-", ny, "-", nz, ".json")
  if !isfile(filename)
    border = computeOriented3Border(nx, ny, nz)
    writeBorder(border, filename)
  end
  return filename

end
end
