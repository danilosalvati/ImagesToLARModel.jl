module PngStack2Array3dJulia

using Images # For loading png images
using Colors # For grayscale images
using PyCall
using Clustering
using Logging
@pyimport scipy.ndimage as ndimage

NOISE_SHAPE_DETECT=10

export calculateClusterCentroids, pngstack2array3d, getImageData, convertImages

function convertImages(inputPath, outputPath, bestImage)
  """
  Get all images contained in inputPath directory
  saving them in outputPath directory in png format.
  If images have one of two odd dimensions, they will be resized
  and if folder contains an odd number of images another one will be
  added

  inputPath: Directory containing input images
  outputPath: Temporary directory containing png images
  bestImage: Image chosen for centroids computation

  Returns the new name for the best image
  """

  imageFiles = readdir(inputPath)
  numberOfImages = length(imageFiles)
  outputPrefix = ""
  for i in 1: length(string(numberOfImages)) - 1
    outputPrefix = string(outputPrefix,"0")
  end 
  
  newBestImage = ""
  imageNumber = 0
  for imageFile in imageFiles
    img = imread(string(inputPath, imageFile))
    rgb_img = convert(Image{ColorTypes.RGB}, img)
    gray_img = convert(Image{ColorTypes.Gray}, rgb_img) 
    # resizing images if they do not have even dimensions
    dim = size(img)
    if(dim[1] % 2 != 0)
      debug("Image has odd x; resizing")
      xrange = 1: dim[1] - 1
    else
      xrange = 1: dim[1]
    end

    if(dim[2] % 2 != 0)
      debug("Image has odd y; resizing")
      yrange = 1: dim[2] - 1
    else
      yrange = 1: dim[2]
    end

    img = subim(gray_img, xrange, yrange) 
    outputFilename = string(outputPath, outputPrefix[length(string(imageNumber)):end],
                              imageNumber,".png")
    imwrite(img, outputFilename)

    # Searching the best image
    if(imageFile == bestImage)
      newBestImage = string(outputPrefix[length(string(imageNumber)):end],
                                imageNumber,".png")
    end
    imageNumber += 1 
    # Denoising
    imArray = raw(img)
    imArray = ndimage.median_filter(imArray, NOISE_SHAPE_DETECT) 
    
    img = grayim(imArray)
    imwrite(img, outputFilename)

  end

  # Adding another image if they are odd
  if(numberOfImages % 2 != 0)
    debug("Odd images, adding one")  
    imageWidth, imageHeight = getImageData(string(outputPath, "/", newBestImage))
    
    if(imageWidth % 2 != 0)
      imageWidth -= 1
    end
    
    if(imageHeight % 2 != 0)
      imageHeight -= 1
    end  
    
    imArray = zeros(Uint8, imageWidth, imageHeight)
    img = grayim(imArray)
    outputFilename = string(outputPath, "/", 
                        outputPrefix[length(string(imageNumber)):end], imageNumber,".png")
  end 

  return newBestImage
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

function calculateClusterCentroids(path, image, numberOfClusters = 2)
  """
  Loads an image and calculate cluster centroids for segmentation

  path: Path of the image folder
  image: name of the image
  numberOfClusters: number of desidered clusters
  """
  imageFilename = string(path, image)

  img = imread(imageFilename) # Open png image with Julia Package

  imArray = raw(img)

  imageWidth = size(imArray)[1]
  imageHeight = size(imArray)[2]

  # Getting pixel values and saving them with another shape
  image3d = Array(Array{Uint8,2}, 0)

  # Inserting page on another list and reshaping
  push!(image3d, imArray)
  pixel = reshape(image3d[1], (imageWidth * imageHeight), 1)

  centroids = kmeans(convert(Array{Float64},transpose(pixel)), 2).centers

  return convert(Array{Uint8}, trunc(centroids))

end

function pngstack2array3d(path, minSlice, maxSlice, centroids)
  """
  Import a stack of PNG images into a 3d array

  path: path of images directory
  minSlice and maxSlice: number of first and last slice
  centroids: centroids for image segmentation
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

    # Inserting page on another list and reshaping
    push!(image3d, imArray)

  end

  # Quantization
  for page in 1:length(image3d)

    # Image Quantization
    debug("page = ", page)
    debug("image3d[page] dimensions: ", size(image3d[page])[1], "\t", size(image3d[page])[2])
    pixel = reshape(image3d[page], size(image3d[page])[1] * size(image3d[page])[2] , 1)
    qnt = kmeans!(convert(Array{Float64},transpose(pixel)),
                convert(Array{Float64},centroids)).assignments

    # Reshaping quantization result
    centers_idx = reshape(qnt, size(image3d[page],1), size(image3d[page],2))

    # Inserting quantized values into 3d image array
    tmp = Array(Uint8, size(image3d[page],1), size(image3d[page],2))

    for j in 1:size(image3d[1],2)
      for i in 1:size(image3d[1],1)
        tmp[i,j] = centroids[centers_idx[i,j]]
      end
    end

    image3d[page] = tmp 

  end

  return image3d
end

end
