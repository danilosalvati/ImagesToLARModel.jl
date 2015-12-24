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

function convertImages(inputPath, outputPath,
                       crop = Void, noise_shape_detect = 0, threshold = Void)
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
        outputFilename = string(outputPath, "/", imageFiles[end][1:rsearch(imageFiles[end], ".")[1]],
                                "-added-", i ,".png")
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
