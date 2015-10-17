push!(LOAD_PATH, "../../")
import PngStack2Array3dJulia
using Base.Test

function testGetImageData()
  """
  Test function for getImageData
  """

  width, height = PngStack2Array3dJulia.getImageData("images/0.png")

  @test width == 50
  @test height == 50

end

function testCalculateClusterCentroids()
  """
  Test function for calculateClusterCentroids
  """
  path = "images/"
  image = 0
  centroids = PngStack2Array3dJulia.calculateClusterCentroids(path, image, 2)

  expected = [0, 253]
  centroids = vec(reshape(centroids, 1, 2))

  @test sort(centroids) == expected
end

function testPngstack2array3d()
  """
  Test function for pngstack2array3d
  """
  path = "images/"
  minSlice = 0
  maxSlice = 4
  centroids = PngStack2Array3dJulia.calculateClusterCentroids(path, 0, 2)
  image3d = PngStack2Array3dJulia.pngstack2array3d(path, minSlice, maxSlice, centroids)

  @test size(image3d)[1] == 5
  @test size(image3d[1])[1] == 50
  @test size(image3d[1])[2] == 200

end

function executeAllTests()
  @time testCalculateClusterCentroids()
  @time testPngstack2array3d()
  @time testGetImageData()
  println("Tests completed.")
end

executeAllTests()

