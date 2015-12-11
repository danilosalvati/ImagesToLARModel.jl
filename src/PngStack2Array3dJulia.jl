module PngStack2Array3dJulia

using Images # For loading png images
using Colors # For grayscale images
using PyCall
using Clustering
using Logging
@pyimport scipy.ndimage as ndimage

export calculateClusterCentroids, pngstack2array3d, getImageData, convertImages

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

function convertImages(inputPath, outputPath,
                       crop = Void, noise_shape_detect = 0)
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
  """

  imageFiles = readdir(inputPath)
  
  for imageFile in imageFiles
    img = imread(string(inputPath, imageFile))
    rgb_img = convert(Image{ColorTypes.RGB}, img)
    gray_img = convert(Image{ColorTypes.Gray}, rgb_img) 
    if(crop!= Void)
      gray_img = resizeImage(gray_img, crop)
    end 

    # Denoising
    if noise_shape_detect != 0
      imArray = raw(gray_img)
      imArray = ndimage.median_filter(imArray, noise_shape_detect)
      gray_img = grayim(imArray)
    end 
    
   outputFilename = string(outputPath, imageFile[1:rsearch(imageFile, ".")[1]], "png")
   imwrite(gray_img, outputFilename)

  end

  # Adding another image if they are odd
  if(length(imageFiles) % 2 != 0)
    debug("Odd images, adding one")  
    imageWidth, imageHeight = getImageData(string(outputPath, "/", imageFiles[1]))
    
    if(imageWidth % 2 != 0)
      imageWidth -= 1
    end
    
    if(imageHeight % 2 != 0)
      imageHeight -= 1
    end  
    
    imArray = zeros(Uint8, imageWidth, imageHeight)
    img = grayim(imArray)
    outputFilename = string(outputPath, "/", "zz.png")
    imwrite(img, outputFilename)
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
    kmeansResults = kmeans!(convert(Array{Float64},transpose(pixel)),
                    convert(Array{Float64},centroids))

    qnt = kmeansResults.assignments
    centers = kmeansResults.centers
    if(centers[1] == centers[2])
      # The image has only a value
      index = findmin([abs(centroids[1]-centers[1]),abs(centroids[2]-centers[1])])[2]
      qnt = fill(index, size(qnt))
    end

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
