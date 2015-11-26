module ImagesConversion

import GenerateBorderMatrix
import PngStack2Array3dJulia
import Lar2Julia
import Model2Obj
import LARUtils
import Smoother

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


function iterateOnBlocks(inputDirectory,
                         imageHeight, imageWidth, imageDepth,
                         imageDx, imageDy, imageDz,
                         processFunction, outputDirectory,
                         centroidsCalc, boundaryMat)
  """
  Simple function that iterates on blocks for executing
  a task described by a processFunction

  inputDirectory: Directory which contains input files for the process function
  imageHeight, imageWidth, imageDepth: Images sizes
  imageDx, imageDy, imageDz: Sizes of cells grid
  processFunction: Function that will be executed on a separate task on
  the entire z-Block
  outputDirectory: Directory which will contains the output
  centroidsCalc: Centroids from the best image
  boundaryMat: Boundary operator for the chosen grid
  """

  beginImageStack = 0
  endImage = beginImageStack

  tasks = Array(RemoteRef, 0)
  for zBlock in 0:(imageDepth / imageDz - 1)
    startImage = endImage
    endImage = startImage + imageDz
    task = @spawn processFunction(inputDirectory,
                                   startImage, endImage,
                                   imageDx, imageDy,
                                   imageWidth, imageHeight,
                                   outputDirectory,
                                   centroidsCalc, boundaryMat)                                  
    push!(tasks, task)
  end

  # Waiting for tasks
  for task in tasks
    wait(task)
  end
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
  
  # Starting pipeline conversion
  info("Starting images conversion")
@time iterateOnBlocks(sliceDirectory,
                    imageHeight, imageWidth, imageDepth,
                    imageDx, imageDy, imageDz,
                    imageConversionProcess, outputDirectory,
                    centroidsCalc, boundaryMat) 

  info("Merging boundaries")
@time iterateOnBlocks(string(outputDirectory, "MODELS"),
                    imageHeight, imageWidth, imageDepth,
                    imageDx, imageDy, imageDz,
                    mergeBoundariesProcess, None,
                    None, None) 
                  
  info("Merging blocks")
@time iterateOnBlocks(string(outputDirectory, "MODELS"),
                    imageHeight, imageWidth, imageDepth,
                    imageDx, imageDy, imageDz,
                    mergeBlocksProcess, None,
                    None, None) 

  info("Smoothing models")
@time smoothBlocks(string(outputDirectory, "MODELS"),
                imageHeight, imageWidth, imageDepth,
                imageDx, imageDy, imageDz) 

  info("Merging obj models")
  if parallelMerge
    @time Model2Obj.mergeObjParallel(string(outputDirectory, "MODELS"))
  else
    @time Model2Obj.mergeObj(string(outputDirectory, "MODELS")) 
  end   
end


function imageConversionProcess(sliceDirectory,
                              startImage, endImage,
                              imageDx, imageDy,
                              imageWidth, imageHeight,
                              outputDirectory,
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
      xEnd = xStart + imageDx
      yEnd = yStart + imageDy
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
      zStart = startImage
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
        models = LARUtils.computeModelAndBoundaries(nx, ny, nz,
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

function mergeBoundariesProcess(modelDirectory,
                                  startImage, endImage,
                                  imageDx, imageDy,
                                  imageWidth, imageHeight,
                                  outputDirectory = None,
                                  centroidsCalc = None, boundaryMat = None)
  """
  Helper function for mergeBoundaries.
  It is executed on different processes

  modelDirectory: Directory containing model files
  startImage: Block start image
  endImage: Block end image
  imageDx, imageDy: x and y sizes of the grid
  imageWidth, imageHeight: Width and Height of the image
  """
  for xBlock in 0:(imageHeight / imageDx - 1)
    for yBlock in 0:(imageWidth / imageDy - 1)

      # Merging right Boundary
      firstPath = string(modelDirectory, "/right_output_", xBlock, "-", yBlock,
                        "_", startImage, "_", endImage)
      secondPath = string(modelDirectory, "/left_output_", xBlock, "-", yBlock + 1,
                        "_", startImage, "_", endImage)
      mergeBoundariesAndRemoveDuplicates(firstPath, secondPath)

      # Merging top boundary
      firstPath = string(modelDirectory, "/top_output_", xBlock, "-", yBlock,
                         "_", startImage, "_", endImage)
      secondPath = string(modelDirectory, "/bottom_output_", xBlock, "-", yBlock,
                         "_", endImage, "_", endImage + (endImage - startImage))
      mergeBoundariesAndRemoveDuplicates(firstPath, secondPath)

      # Merging front boundary
      firstPath = string(modelDirectory, "/front_output_", xBlock, "-", yBlock,
                        "_", startImage, "_", endImage)
      secondPath = string(modelDirectory, "/back_output_", xBlock + 1, "-", yBlock,
                        "_", startImage, "_", endImage)
      mergeBoundariesAndRemoveDuplicates(firstPath, secondPath)
    end
  end
end 

function mergeBoundariesAndRemoveDuplicates(firstPath, secondPath)
  """
  Merge two boundary files removing common faces between
  them

  firstPath, secondPath: Prefix of paths to merge
  """

  firstPathV = string(firstPath, "_vtx.stl")
  firstPathFV = string(firstPath, "_faces.stl")

  secondPathV = string(secondPath, "_vtx.stl")
  secondPathFV = string(secondPath, "_faces.stl")

  if(isfile(firstPathV) && isfile(secondPathV))

    V, FV = Model2Obj.getModelsFromFiles([firstPathV, secondPathV],
                                         [firstPathFV, secondPathFV])

    # Writing model to file
    rm(firstPathV)
    rm(firstPathFV)
    rm(secondPathV)
    rm(secondPathFV)
    Model2Obj.writeToObj(V, FV, firstPath)
  end
end 

function mergeBlocksProcess(modelDirectory,
                              startImage, endImage,
                              imageDx, imageDy,
                              imageWidth, imageHeight,
                              outputDirectory = None,
                              centroidsCalc = None, boundaryMat = None)
  """
  Helper function for mergeBlocks.
  It is executed on different processes

  modelDirectory: Directory containing model files
  startImage: Block start image
  endImage: Block end image
  imageDx, imageDy: x and y sizes of the grid
  imageWidth, imageHeight: Width and Height of the image
  """
  for xBlock in 0:(imageHeight / imageDx - 1)
    for yBlock in 0:(imageWidth / imageDy - 1)

      blockCoordsV = string(xBlock, "-", yBlock, "_", startImage,
                            "_", endImage, "_vtx.stl")
      blockCoordsFV = string(xBlock, "-", yBlock, "_", startImage,
                            "_", endImage, "_faces.stl")

      arrayV = [string(modelDirectory, "/left_output_", blockCoordsV),
                string(modelDirectory, "/right_output_", blockCoordsV),
                string(modelDirectory, "/top_output_", blockCoordsV),
                string(modelDirectory, "/bottom_output_", blockCoordsV),
                string(modelDirectory, "/front_output_", blockCoordsV),
                string(modelDirectory, "/back_output_", blockCoordsV),
                string(modelDirectory, "/model_output_", blockCoordsV)]

      arrayFV = [string(modelDirectory, "/left_output_", blockCoordsFV),
                 string(modelDirectory, "/right_output_", blockCoordsFV),
                 string(modelDirectory, "/top_output_", blockCoordsFV),
                 string(modelDirectory, "/bottom_output_", blockCoordsFV),
                 string(modelDirectory, "/front_output_", blockCoordsFV),
                 string(modelDirectory, "/back_output_", blockCoordsFV),
                 string(modelDirectory, "/model_output_", blockCoordsFV)]

      V, FV = Model2Obj.getModelsFromFiles(arrayV, arrayFV)
      for i in 1:length(arrayV)
        if(isfile(arrayV[i]))
          rm(arrayV[i])
          rm(arrayFV[i])
        end
      end

      Model2Obj.writeToObj(V, FV, string(modelDirectory, "/model_output_",
                               xBlock, "-", yBlock, "_", startImage, "_", endImage))
    end
  end
end 

function smoothBlocksProcess(modelDirectory,
                              startImage, endImage,
                              imageDx, imageDy,
                              imageWidth, imageHeight,
                              outputDirectory = None,
                              centroidsCalc = None, boundaryMat = None)
  """
  Smoothes a block in a single process

  modelDirectory: Path of the directory containing all blocks
                  that will be smoothed
  startImage, endImage: start and end image for this block
  imageDx, imageDy: sizes of the grid
  imageWidth, imageHeight: sizes of the images
  """

  for xBlock in 0:(imageHeight / imageDx - 1)
    for yBlock in 0:(imageWidth / imageDy - 1)

      # Loading the current block model
      blockFileV = string(modelDirectory, "/model_output_", xBlock, "-", yBlock,
                          "_", startImage, "_", endImage, "_vtx.stl")
      blockFileFV = string(modelDirectory, "/model_output_", xBlock, "-", yBlock,
                          "_", startImage, "_", endImage, "_faces.stl")

      if isfile(blockFileV)
        # Loading only model of the current block
        blockModelV, blockModelFV = Model2Obj.getModelsFromFiles([blockFileV], [blockFileFV])

        # Loading a unique model from this block and its adjacents
        modelsFiles = Array(String, 0)
        for x in xBlock - 1:xBlock + 1
          for y in yBlock - 1:yBlock + 1
            for z in range(startImage - (endImage - startImage),(endImage - startImage), 3)
              push!(modelsFiles, string(modelDirectory, "/model_output_",
                                        x, "-", y, "_", z, "_", z + (endImage - startImage)))
            end
          end
        end

        modelsFilesV = map((s) -> string(s, "_vtx.stl"), modelsFiles)
        modelsFilesFV = map((s) -> string(s, "_faces.stl"), modelsFiles)

        modelV, modelFV = Model2Obj.getModelsFromFiles(modelsFilesV, modelsFilesFV)

        # Now I have to save indices of vertices of the current block model
        blockVerticesIndices = Array(Int, 0)
        for i in 1:length(blockModelV)
          for j in 1:length(modelV)
            if blockModelV[i] == modelV[j]
              push!(blockVerticesIndices, j)
            end
          end

          # Now I can apply smoothing on this model
          V_sm, FV_sm = Smoother.smoothModel(modelV, modelFV)

          # Now I have to get only block vertices and save them on the new model
          V_final = Array(Array{Float64}, 0)
          for i in blockVerticesIndices
            push!(V_final, V_sm[i])
          end
          outputFilename = string(modelDirectory, "/smoothed_output_", xBlock, "-",
                                  yBlock, "_", startImage, "_", endImage)
          Model2Obj.writeToObj(V_final, blockModelFV, outputFilename)
        end
      end
    end
  end
end 

function smoothBlocks(modelDirectory,
                      imageHeight, imageWidth, imageDepth,
                      imageDx, imageDy, imageDz)
  """
  Smoothes all blocks of the
  model
  """
  
  function moveSmoothed(modelDirectory,
                        startImage, endImage,
                        imageDx, imageDy,
                        imageWidth, imageHeight,
                        outputDirectory = None,
                        centroidsCalc = None, boundaryMat = None)

    for xBlock in 0:(imageHeight / imageDx - 1)
      for yBlock in 0:(imageWidth / imageDy - 1)

        f_V = string(modelDirectory, "/smoothed_output_", xBlock, "-", yBlock, "_",
                     startImage, "_", endImage, "_vtx.stl")
        f_FV = string(modelDirectory, "/smoothed_output_", xBlock, "-", yBlock, "_",
                     startImage, "_", endImage, "_faces.stl")

        if(isfile(f_V))
          if VERSION >= v"0.4"
            mv(f_V, replace(f_V, "smoothed", "model"), remove_destination = true)
            mv(f_FV, replace(f_FV, "smoothed", "model"), remove_destination = true)
          else
            mv(f_V, replace(f_V, "smoothed", "model"))
            mv(f_FV, replace(f_FV, "smoothed", "model"))
          end

        end
      end
    end

  end 
  
  iterations = 3
  for i in 1:iterations
    info("Iteration ", i)

    iterateOnBlocks(modelDirectory,
                    imageHeight, imageWidth, imageDepth,
                    imageDx, imageDy, imageDz,
                    smoothBlocksProcess,
                    None, None, None)

    iterateOnBlocks(modelDirectory,
                    imageHeight, imageWidth, imageDepth,
                    imageDx, imageDy, imageDz,
                    moveSmoothed,
                    None, None, None)
  end

end 

end
