module PngStack2Array3dJulia

using Images # For loading png images
using Colors # For grayscale images
using PyCall
using Clustering
using Logging
@pyimport scipy.ndimage as ndimage

export pngstack2array3d, getImageData, convertImages

function resizeImage(image, crop)
  """
  Utility function for images resize
  
  image: the input image
  crop: a list containing the crop parameters 
        for the three dimensions 
  
  returns the resized image
  """
  dim = size(image)
  if(crop[1][2] > dim[1])
    # Extending the images on the x axis
    imArray = raw(image)
    zeroArray = zeros(Uint8, dim[2])
    for i in (1 : (crop[1][2] - dim[1]))
      imArray = vcat(imArray, transpose(zeroArray))
    end
    image = grayim(imArray)
  end
  
  if(crop[2][2] > dim[2])
    # Extending the images on the y axis
    imArray = raw(image)
    zeroArray = zeros(Uint8, size(image)[1])
    for i in (1: (crop[2][2] - dim[2]))
      imArray = hcat(imArray, zeroArray)
    end
    image = grayim(imArray)
  end
  return subim(image, crop[1][1]:crop[1][2], crop[2][1]:crop[2][2])
end 

function clusterImage(imArray)
  """
  Get a binary representation of an image returning
  a two-color image using clustering
  
  imArray: array containing pixel values
  
  return the imArray with only two different values
  """
  
  imageWidth = size(imArray)[1]
  imageHeight = size(imArray)[2]

  # Formatting data for clustering
  image3d = Array(Array{Uint8,2}, 0)
  push!(image3d, imArray)
  pixels = reshape(image3d[1], (imageWidth * imageHeight), 1)
  
  # Computing assignments from the raw data
  kmeansResults = kmeans(convert(Array{Float64}, transpose(pixels)), 2)
  
  qnt = kmeansResults.assignments
  centers = kmeansResults.centers
  
  if(centers[1] == centers[2])
    if centers[1] < 30 # I assume that a full image can have light gray pixels
      qnt = fill(0x00, size(qnt))
    else
      qnt = fill(0xff, size(qnt))
    end
  else
    minIndex = findmin(centers)[2]
    qnt = map(x-> if x == minIndex return 0x00 else return 0xff end, qnt)
  end
  
  return reshape(qnt, imageWidth, imageHeight)  
end 

function visitFromNode(node, graph, visited)
  """
  Visit a graph starting from a node using a DFS

  node: the starting node
  graph: the matrix representation of the graph
  visited: the visited nodes
  """
  toVisit = Array(Int, 0)
  visitedNodes = Array(Int, 0)
  push!(toVisit, node)
  while (length(toVisit) != 0)
    n = pop!(toVisit)
    if !in(n, visited)
      push!(visited, n)
      push!(visitedNodes, n)
      adj_list = adjacentPixels(graph, n)
      for adj in adj_list
        push!(toVisit, adj)
      end
    end
  end
  return visitedNodes
end

function pixelIndex(x, y, z, nx, ny)
  """
  Given the coordinates of a pixel
  of the image matrix return the index
  of the linearized matrix
  """
  return x + nx * (y - 1) + nx * ny * (z - 1)
end

function pixelCoords(ind, nx, ny)
  """
  Given the index of a pixel
  returns the coordinates of the pixel
  """

  xCoord = (ind - 1) % nx + 1

  yCoord = convert(Int, trunc((ind - 1) % (nx * ny)/ nx)) + 1

  zCoord = convert(Int, trunc((ind - 1) / (nx * ny))) + 1

  return xCoord, yCoord, zCoord
end

function adjacentPixels(imageArray, pixel)
  """
  Find the pixels which are adjacent
  to a given one

  imageArray: the array containing the image
  pixel: the index of the pixel we are querying
  """
  nx = size(imageArray[1])[1]
  ny = size(imageArray[1])[2]
  adjs = Array(Int, 0)
  xPixel, yPixel, zPixel = pixelCoords(pixel, nx, ny)
  # Querying adjacent pixels
  for z in max(1, zPixel - 1) : min(zPixel + 1, length(imageArray))
    for y in max(1, yPixel - 1) : min(yPixel + 1, nx)
      for x in max(1, xPixel - 1) : min(xPixel + 1, ny)
        if(x == xPixel || y == yPixel)
          index = pixelIndex(x, y, z, nx, ny)
          if(index != pixel && imageArray[z][x, y] != 0x00)
          push!(adjs, index)
          end
        end
      end
    end
  end
  return adjs
end

function filter3DProcessFunction(blockFiles, threshold)
  """
  Process function for the 3D filter.
  It takes a single block and processes all files
  on a single process
  
  blockFiles: The array of files for the block computed
              by this function
  threshold: The threshold for data filtering
  """
  zDim = length(blockFiles)
  imageArray = Array(Array{Uint8,2}, zDim)
  for i in 1: zDim
      img = imread(blockFiles[i])
      imageArray[i] = raw(img)
  end

  # Now I can start navigation of the graph determined
  # by these images
  visited = Array(Int, 0)
  nx = size(imageArray[1])[1]
  ny = size(imageArray[1])[2]
  for i in 1: (zDim * nx * ny)
    xPixel, yPixel, zPixel = pixelCoords(i, nx, ny)
    if imageArray[zPixel][xPixel, yPixel]!= 0x00 && !in(i, visited)
      visitedPixels = visitFromNode(i, imageArray, visited)
      if length(visitedPixels) < threshold
        for pixel in visitedPixels
          x, y, z = pixelCoords(pixel, nx, ny)
          imageArray[z][x, y] = 0x00
        end
      end
    end
  end
  
  # Now I can write the results on file
  for i in 1: zDim
    imwrite(grayim(imageArray[i]), blockFiles[i])
  end
end

function imageFilter3D(imageDirectory, threshold, zDim = 0)
  """
  Implementation of a filter for a stack of images
  It traverses a stack of images loading zDim images
  at once finding the adjacent pixels. If the number of
  adjacent pixels is less than a threshold, the pixels
  will be deleted

  imageDirectory: The directory containg the images
  threshold: the minimum number of adjacent pixels for the result
  zDim: the number of images to load at once
  """
  imageFiles = readdir(imageDirectory)
  imageFiles = map((s) -> string(imageDirectory, s), imageFiles)

  if zDim == 0
    zDim = length(imageFiles)
  end
  
  numberOfBlocks = convert(Int, trunc(length(imageFiles)/zDim))

  if length(imageFiles) % zDim != 0
    numberOfBlocks += 1
  end
  
  tasks = Array(RemoteRef, 0)
  for zBlock in 1: numberOfBlocks
    endBlock = min(zBlock * zDim, length(imageFiles))
    startBlock = (zBlock - 1) * zDim + 1
    blockFiles = imageFiles[startBlock: endBlock]
    task = @spawn filter3DProcessFunction(blockFiles, threshold)
    push!(tasks, task)
  end
  # Waiting for task completion
  for task in tasks
    wait(task)
  end
end 

function convertImages(inputPath, outputPath,
                       crop = Void, noise_shape_detect = 0, threshold = Void,
                       threshold3d = 0, zDim = 0)
  """
  Get all images contained in inputPath directory
  saving them in outputPath directory in png format.
  Images will be resized according with the crop parameter
  and if folder contains an odd number of images another one will be
  added

  inputPath: Directory containing input images
  outputPath: Temporary directory containing png images
  crop: Parameter for images resizing (they can be
        extended or cropped)
  noise_shape_detect: Shape for the denoising filter
  threshold: Threshold for the raw data. All pixel under it
             will we set to black, otherwise they will be set to white
  """

  imageFiles = readdir(inputPath)
  
  #Resizing on the z axis
  if(crop!= Void)
    numberOfImages = length(imageFiles)
    if(crop[3][2] > numberOfImages)
      imageWidth = crop[1][2] - crop[1][1] + 1
      imageHeight = crop[2][2] - crop[2][1] + 1
      for i in 1 : crop[3][2] - numberOfImages
        imArray = zeros(Uint8, imageWidth, imageHeight)
        img = grayim(imArray)
        outputFilename = string(outputPath, "/", imageFiles[end][1:rsearch(imageFiles[end], ".")[1] - 1],
                                "_added-", i ,".png")
        imwrite(img, outputFilename)
      end 
    end
    imageFiles = imageFiles[crop[3][1]:min(numberOfImages, crop[3][2])]
  end 
  
  for imageFile in imageFiles
    img = imread(string(inputPath, imageFile))
    rgb_img = convert(Image{ColorTypes.RGB}, img)
    gray_img = convert(Image{ColorTypes.Gray}, rgb_img) 
    if(crop!= Void)
      # Resize images on x-axis and y-axis
      gray_img = resizeImage(gray_img, crop)
    end 
    
    imArray = raw(gray_img)
    # Denoising
    if noise_shape_detect != 0
      imArray = ndimage.median_filter(imArray, noise_shape_detect)
    end 
    if(threshold != Void)
      imArray = map(x-> if x > threshold return 0xff else return 0x00 end, imArray)
    else
      imArray = clusterImage(imArray)
    end
    gray_img = grayim(imArray) 
   
   outputFilename = string(outputPath, imageFile[1:rsearch(imageFile, ".")[1]], "png")
   imwrite(gray_img, outputFilename)

  end
  # Filtering out non-relevant parts of the model
  if(threshold3d != 0)
    imageFilter3D(outputPath, threshold3d, zDim)
  end 
end

function getImageData(imageFile)
  """
  Get width and height from a png image
  """

  input = open(imageFile, "r")
  data = readbytes(input, 24)
  
  if (convert(Array{Int},data[1:8]) != reshape([137 80 78 71 13 10 26 10],8))
    error("This is not a valid png image")
  end

  w = data[17:20]
  h = data[21:24]

  width = reinterpret(Int32, reverse(w))[1]
  height = reinterpret(Int32, reverse(h))[1]

  close(input)

  return width, height
end

function pngstack2array3d(path, minSlice, maxSlice)
  """
  Import a stack of PNG images into a 3d array

  path: path of images directory
  minSlice and maxSlice: number of first and last slice
  """

  # image3d contains all images values
  image3d = Array(Array{Uint8,2}, 0)

  debug("maxSlice = ", maxSlice, " minSlice = ", minSlice)
  files = readdir(path)

  for slice in minSlice : (maxSlice - 1)
    debug("slice = ", slice)
    imageFilename = string(path, files[slice + 1])
    debug("image name: ", imageFilename)
    img = imread(imageFilename) # Open png image with Julia Package
    imArray = raw(img) # Putting pixel values into RAW 3d array
    debug("imArray size: ", size(imArray))

    # Inserting page on another list
    push!(image3d, imArray)

  end
  return image3d
end

end
