module ImagesConvertion

require("generateBorderMatrix.jl")
require("pngStack2Array3dJulia.jl")
require("lar2Julia.jl")
require("model2Obj.jl")

import GenerateBorderMatrix
import PngStack2Array3dJulia
import Lar2Julia
import Model2Obj

import JSON

using PyCall
@pyimport scipy.sparse as Pysparse

using Logging

export images2LARModel

"""
This is main module for converting a stack
of images into a 3d model
"""

function images2LARModel(nx, ny, nz, bestImage, inputDirectory, outputDirectory)
  """
  Convert a stack of images into a 3d model
  """

  info("Starting model creation")

  numberOfClusters = 2 # Number of clusters for
                       # images segmentation

  imageWidth, imageHeight = PngStack2Array3dJulia.getImageData(string(inputDirectory,bestImage))
  imageDepth = length(readdir(inputDirectory))

  # Computing border matrix
  info("Computing border matrix")
  try
    mkdir(string(outputDirectory, "BORDERS"))
  catch
  end
  borderFilename = GenerateBorderMatrix.getOriented3BorderPath(string(outputDirectory, "BORDERS"), nx, ny, nz)

  # Starting images convertion and border computation
  info("Starting images convertion")
  startImageConvertion(inputDirectory, bestImage, outputDirectory, borderFilename,
                       imageHeight, imageWidth, imageDepth,
                       nx, ny, nz,
                       numberOfClusters)

end


function startImageConvertion(sliceDirectory, bestImage, outputDirectory, borderFilename,
                              imageHeight, imageWidth, imageDepth,
                              imageDx, imageDy, imageDz,
                              numberOfClusters)
  """
  Support function for converting a stack of images into a model

  sliceDirectory: directory containing the image stack
  imageForCentroids: image chosen for centroid computation
  """

  info("Moving images into temp directory")
  try
    mkdir(string(outputDirectory, "TEMP"))
  catch
  end

  tempDirectory = string(outputDirectory,"TEMP/")

  newBestImage = PngStack2Array3dJulia.convertImages(sliceDirectory, tempDirectory, bestImage)

  # Create clusters for image segmentation
  info("Computing image centroids")
  debug("Best image = ", bestImage)
  centroidsCalc = PngStack2Array3dJulia.calculateClusterCentroids(tempDirectory, newBestImage, numberOfClusters)
  debug(string("centroids = ", centroidsCalc))

  try
    mkdir(string(outputDirectory, "BORDERS"))
  catch
  end
  debug(string("Opening border file: ", "border_", imageDx, "-", imageDy, "-", imageDz, ".json"))
  boundaryMat = getBorderMatrix(string(outputDirectory,"BORDERS/","border_", imageDx, "-",
                                       imageDy, "-", imageDz, ".json"))
  beginImageStack = 0
  endImage = beginImageStack

  info("Converting images into a 3d model")
  for zBlock in 0:(imageDepth / imageDz - 1)
    startImage = endImage
    endImage = startImage + imageDz
    info("StartImage = ", startImage)
    info("endImage = ", endImage)
    info(string("Start process convertion process ", zBlock))
    imageConvertionProcess(tempDirectory, outputDirectory,
                           beginImageStack, startImage, endImage,
                           imageDx, imageDy, imageDz,
                           imageHeight, imageWidth,
                           centroidsCalc, boundaryMat)
  end

  # TODO: add something for waiting all processes
  info("Merging obj models")
  Model2Obj.mergeObj(string(outputDirectory,"MODELS"))

end

function imageConvertionProcess(sliceDirectory, outputDirectory,
                                beginImageStack, startImage, endImage,
                                imageDx, imageDy, imageDz,
                                imageHeight, imageWidth,
                                centroids, boundaryMat)
  """
  Support function for converting a stack of image on a single
  independent process
  """

  info("Transforming png data into 3d array")
  theImage = PngStack2Array3dJulia.pngstack2array3d(sliceDirectory, startImage, endImage, centroids)

  centroidsSorted = sort(vec(reshape(centroids, 1, 2)))
  foreground = centroidsSorted[2]
  background = centroidsSorted[1]
  debug(string("background = ", background, " foreground = ", foreground))
  for xBlock in 0:(imageHeight / imageDx - 1)
    for yBlock in 0:(imageWidth / imageDy - 1)
      yStart = xBlock * imageDx
      xStart = yBlock * imageDy
      #xEnd = xStart + imageDx
      #yEnd = yStart + imageDy
      xEnd = xStart + imageDy
      yEnd = yStart + imageDx
      debug("***********")
      debug(string("xStart = ", xStart, " xEnd = ", xEnd))
      debug(string("yStart = ", yStart, " yEnd = ", yEnd))
      debug("theImage dimensions: ", size(theImage)[1], " ", size(theImage[1])[1], " ", size(theImage[1])[2])

      # Getting a slice of theImage array
      image = Array(Uint8, (convert(Int32, length(theImage)), convert(Int32, xEnd - xStart), convert(Int32, yEnd - yStart)))
      debug("image size: ", size(image))
      for z in 1:length(theImage)
        for x in 1 : (xEnd - xStart)
          for y in 1 : (yEnd - yStart)
            image[z, x, y] = theImage[z][x + xStart, y + yStart]
          end
        end
      end

      nx, ny, nz = size(image)
      chains3D = Array(Uint8, 0)
      zStart = startImage - beginImageStack
      for y in 0:(nx - 1)
        for x in 0:(ny - 1)
          for z in 0:(nz - 1)
            if(image[z + 1, x + 1, y + 1] == foreground)
              push!(chains3D, y + ny * (x + nx * z))
            end
          end
        end
      end

      if(length(chains3D) != 0)
        # Computing boundary chain
        debug("chains3d = ", chains3D)
        debug("Computing boundary chain")
        objectBoundaryChain = Lar2Julia.larBoundaryChain(boundaryMat, chains3D)
        debug("Converting models into obj")
        try
          mkdir(string(outputDirectory, "MODELS"))
        catch
        end
        # IMPORTANT: inverting xStart and yStart for obtaining correct rotation of the model
        outputFilename = string(outputDirectory, "MODELS/model-", xBlock, "-", yBlock, "_output_", startImage, "_", endImage)
        Model2Obj.writeToObj(imageDx, imageDy, imageDz, yStart, xStart, zStart, objectBoundaryChain, outputFilename)
      else
        debug("Model is empty")
      end
    end
  end
end

function getBorderMatrix(borderFilename)
  """
  TO REMOVE WHEN PORTING OF LARCC IN JULIA IS COMPLETED

  Get the border matrix from json file and convert it in
  CSC format
  """
  # Loading borderMatrix from json file
  borderData = JSON.parsefile(borderFilename)
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

  # Converting csr matrix to csc
  csrBorderMatrix = Pysparse.csr_matrix((data,col,row), shape=(borderData["ROWCOUNT"],borderData["COLCOUNT"]))
  denseMatrix = pycall(csrBorderMatrix["toarray"],PyAny)

  cscBoundaryMat = sparse(denseMatrix)

  return cscBoundaryMat

end

end
