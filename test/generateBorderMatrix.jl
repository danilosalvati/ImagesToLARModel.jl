push!(LOAD_PATH, "../../")
import GenerateBorderMatrix
import JSON
using Base.Test

function testComputeOriented3Border()
  """
  Test function for computeOriented3Border
  """
  boundaryMatrix = GenerateBorderMatrix.computeOriented3Border(2,2,2)

  rowcount = boundaryMatrix[:shape][1]
  @test rowcount == 36
  colcount = boundaryMatrix[:shape][2]
  @test colcount == 8
  row = boundaryMatrix[:indptr]
  @test row == [0,1,2,3,4,5,7,8,9,11,12,13,15,17,18,19,20,22,23,24,26,27,29,30,32,34,35,37,39,41,42,43,44,45,46,47,48]
  col = boundaryMatrix[:indices]
  @test col == [0,0,0,1,1,0,1,1,2,0,2,2,3,1,3,2,3,3,2,3,0,4,4,4,1,5,5,4,5,5,2,6,4,6,6,3,7,5,7,6,7,7,6,7,4,5,6,7]
  data = boundaryMatrix[:data]
  @test data == [-1,1,-1,-1,1,1,-1,1,-1,-1,1,-1,-1,-1,1,1,-1,1,-1,-1,1,-1,1,-1,1,-1,1,1,-1,1,1,-1,-1,1,-1,1,-1,-1,1,1,-1,1,-1,-1,1,1,1,1]

end

function testWriteBorder()
  """
  Test for writeBorder
  """
  boundaryMatrix = GenerateBorderMatrix.computeOriented3Border(2,2,2)
  filename = "borderFile"

  GenerateBorderMatrix.writeBorder(boundaryMatrix, filename)
  @test isfile(filename)

  # Loading borderMatrix from json file
  borderData = JSON.parsefile(filename)
  row = Array(Int64, length(borderData["ROW"]))
  col = Array(Int64, length(borderData["COL"]))
  data = Array(Int64, length(borderData["DATA"]))

  @test borderData["ROW"] == [0,1,2,3,4,5,7,8,9,11,12,13,15,17,18,19,20,22,23,24,26,27,29,30,32,34,35,37,39,41,42,43,44,45,46,47,48]
  @test borderData["COL"] == [0,0,0,1,1,0,1,1,2,0,2,2,3,1,3,2,3,3,2,3,0,4,4,4,1,5,5,4,5,5,2,6,4,6,6,3,7,5,7,6,7,7,6,7,4,5,6,7]
  @test borderData["DATA"] == [-1,1,-1,-1,1,1,-1,1,-1,-1,1,-1,-1,-1,1,1,-1,1,-1,-1,1,-1,1,-1,1,-1,1,1,-1,1,1,-1,-1,1,-1,1,-1,-1,1,1,-1,1,-1,-1,1,1,1,1]

  rm(filename)

end

function executeAllTests()
  @time testComputeOriented3Border()
  @time testWriteBorder()
  println("Tests completed.")
end

executeAllTests()

