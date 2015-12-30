module GenerateBorderMatrix

type MatrixObject
  ROWCOUNT
  COLCOUNT
  ROW
  COL
  DATA
end 

import LARUtils, Lar2Julia
import JSON

export computeOriented3Border, writeBorder, getOriented3BorderPath, getBorderMatrix


# Compute the 3-border operator
function computeOriented3Border(nx, ny, nz)
  """
  Compute the 3-border matrix
  """
  V, bases = LARUtils.getBases(nx, ny, nz)
  return Lar2Julia.signedCellularBoundary(V, bases)
end 

function writeBorder(boundaryMatrix, outputFile)
  """
  Write 3-border matrix on json file

  boundaryMatrix: matrix to write on file
  outputFile: path of the outputFile
  """

  row = findn(boundaryMatrix)[1]
  col = findn(boundaryMatrix)[2]
  data = nonzeros(boundaryMatrix)

  matrixObj = MatrixObject(0, 0, row, col, data)

  outfile = open(string(outputFile), "w")
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

function getBorderMatrix(borderFilename)
  """
  Get the border matrix from json file and convert it in
  CSC format
  """
  # Loading borderMatrix from json file
  borderData = JSON.parsefile(borderFilename)
  
  # Converting Any arrays into Int arrays
  row = Array(Int64, length(borderData["ROW"]))
  col = Array(Int64, length(borderData["COL"]))
  data = Array(Int64, length(borderData["DATA"]))

  for i in 1: length(borderData["ROW"])
    row[i] = borderData["ROW"][i]
  end

  for i in 1: length(borderData["COL"])
    col[i] = borderData["COL"][i]
  end

  for i in 1: length(borderData["DATA"])
    data[i] = borderData["DATA"][i]
  end
  return sparse(row, col, data)
end 
end
