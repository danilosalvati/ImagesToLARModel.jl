module ImagesConversion

import GenerateBorderMatrix
import PngStack2Array3dJulia
import Lar2Julia
import Model2Obj
import LARUtils

using Logging

export images2LARModel


function images2LARModel(nx, ny, nz, bestImage,
                        inputDirectory, outputDirectory, parallelMerge)
  """
  Convert a stack of images into a 3d model
  """

  info("Starting model creation")

  numberOfClusters = 2 # Number of clusters for
                       # images segmentation

  info("Moving images into temp directory")
  try
    mkdir(string(outputDirectory, "TEMP"))
  catch
  end

  tempDirectory = string(outputDirectory,"TEMP/")

  newBestImage = PngStack2Array3dJulia.convertImages(inputDirectory, tempDirectory,
                                                        bestImage)

  imageWidth, imageHeight = PngStack2Array3dJulia.getImageData(
                                      string(tempDirectory,newBestImage))
  imageDepth = length(readdir(tempDirectory))

  # Computing border matrix
  info("Computing border matrix")
  try
    mkdir(string(outputDirectory, "BORDERS"))
  catch
  end
  borderFilename = GenerateBorderMatrix.getOriented3BorderPath(
                                        string(outputDirectory, "BORDERS"), nx, ny, nz)

  # Starting images conversion and border computation
  info("Starting images conversion")
  startImageConversion(tempDirectory, newBestImage, outputDirectory, borderFilename,
                       imageHeight, imageWidth, imageDepth,
                       nx, ny, nz,
                       numberOfClusters, parallelMerge)

end


function startImageConversion(sliceDirectory, bestImage, outputDirectory, borderFilename,
                              imageHeight, imageWidth, imageDepth,
                              imageDx, imageDy, imageDz,
                              numberOfClusters, parallelMerge)
  """
  Support function for converting a stack of images into a model

  sliceDirectory: directory containing the image stack
  imageForCentroids: image chosen for centroid computation
  """

  # Create clusters for image segmentation
  info("Computing image centroids")
  debug("Best image = ", bestImage)
  centroidsCalc = PngStack2Array3dJulia.calculateClusterCentroids(sliceDirectory,
                                          bestImage, numberOfClusters)
  debug(string("centroids = ", centroidsCalc))

  try
    mkdir(string(outputDirectory, "BORDERS"))
  catch
  end
  debug("Opening border file: border_", imageDx, "-", imageDy, "-", imageDz, ".json")
  boundaryMat = GenerateBorderMatrix.getBorderMatrix(
                                          string(outputDirectory,"BORDERS/","border_",
                                          imageDx, "-", imageDy, "-", imageDz, ".json"))
  
  beginImageStack = 0
  endImage = beginImageStack

  info("Converting images into a 3d model")
  tasks = Array(RemoteRef, 0)
  for zBlock in 0:(imageDepth / imageDz - 1)
    startImage = endImage
    endImage = startImage + imageDz
    info("StartImage = ", startImage)
    info("endImage = ", endImage)

    task = @spawn imageConversionProcess(sliceDirectory, outputDirectory,
                            beginImageStack, startImage, endImage,
                            imageDx, imageDy, imageDz,
                            imageHeight, imageWidth,
                            centroidsCalc, boundaryMat)

    push!(tasks, task)
  end
  
  # Waiting for tasks completion
  for task in tasks
    wait(task)
  end
  info("Merging boundaries")
  # Merge Boundaries files
  Model2Obj.mergeBoundaries(string(outputDirectory, "MODELS"),
                            imageHeight, imageWidth, imageDepth,
                            imageDx, imageDy, imageDz)

  info("Merging blocks")
  Model2Obj.mergeBlocks(string(outputDirectory, "MODELS"),
                            imageHeight, imageWidth, imageDepth,
                            imageDx, imageDy, imageDz)

  info("Merging obj models")
  if parallelMerge
    Model2Obj.mergeObjParallel(string(outputDirectory, "MODELS"))
  else
    Model2Obj.mergeObj(string(outputDirectory, "MODELS"))
  end
  
  end


function imageConversionProcess(sliceDirectory, outputDirectory,
                                beginImageStack, startImage, endImage,
                                imageDx, imageDy, imageDz,
                                imageHeight, imageWidth,
                                centroids, boundaryMat)
  """
  Support function for converting a stack of image on a single
  independent process
  """

  info("Transforming png data into 3d array")
  theImage = PngStack2Array3dJulia.pngstack2array3d(sliceDirectory,
                                                  startImage, endImage, centroids)

  centroidsSorted = sort(vec(reshape(centroids, 1, 2)))
  background = centroidsSorted[1]
  foreground = centroidsSorted[2]
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
      debug("theImage dimensions: ", size(theImage)[1], " ",
                      size(theImage[1])[1], " ", size(theImage[1])[2])

      # Getting a slice of theImage array

      image = Array(Uint8, (convert(Int, length(theImage)), 
                            convert(Int, xEnd - xStart), convert(Int, yEnd - yStart)))
      debug("image size: ", size(image))
      for z in 1:length(theImage)
        for x in 1 : (xEnd - xStart)
          for y in 1 : (yEnd - yStart)
            image[z, x, y] = theImage[z][x + xStart, y + yStart]
          end
        end
      end
      
      
      nz, nx, ny = size(image)
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
        models = LARUtils.computeModelAndBoundaries(imageDx, imageDy, imageDz,
                                                    yStart, xStart, zStart, objectBoundaryChain)

        V, FV = models[1][1] # inside model
        V_left, FV_left = models[2][1]
        V_right, FV_right = models[3][1] # right boundary
        V_top, FV_top = models[4][1] # top boundary
        V_bottom, FV_bottom = models[5][1] # bottom boundary
        V_front, FV_front = models[6][1] # front boundary
        V_back, FV_back = models[7][1] # back boundary
        
        
        # Writing all models on disk
        model_outputFilename = string(outputDirectory, "MODELS/model_output_", xBlock,
                                        "-", yBlock, "_", startImage, "_", endImage)
        Model2Obj.writeToObj(V, FV, model_outputFilename)

        left_outputFilename = string(outputDirectory, "MODELS/left_output_", xBlock,
                                        "-", yBlock, "_", startImage, "_", endImage)
        Model2Obj.writeToObj(V_left, FV_left, left_outputFilename)

        right_outputFilename = string(outputDirectory, "MODELS/right_output_", xBlock,
                                        "-", yBlock, "_", startImage, "_", endImage)
        Model2Obj.writeToObj(V_right, FV_right, right_outputFilename)

        top_outputFilename = string(outputDirectory, "MODELS/top_output_", xBlock,
                                        "-", yBlock, "_", startImage, "_", endImage)
        Model2Obj.writeToObj(V_top, FV_top, top_outputFilename)

        bottom_outputFilename = string(outputDirectory, "MODELS/bottom_output_", xBlock,
                                        "-", yBlock, "_", startImage, "_", endImage)
        Model2Obj.writeToObj(V_bottom, FV_bottom, bottom_outputFilename)

        front_outputFilename = string(outputDirectory, "MODELS/front_output_", xBlock,
                                        "-", yBlock, "_", startImage, "_", endImage)
        Model2Obj.writeToObj(V_front, FV_front, front_outputFilename)

        back_outputFilename = string(outputDirectory, "MODELS/back_output_", xBlock,
                                        "-", yBlock, "_", startImage, "_", endImage)
        Model2Obj.writeToObj(V_back, FV_back, back_outputFilename)

        
      else
        debug("Model is empty")
      end
    end
  end
end 
end
