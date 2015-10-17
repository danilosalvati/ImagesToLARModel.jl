module ImagesToLARModel
"""
Main module for the library. It starts conversion
taking configuration parameters
"""
require("imagesConvertion.jl")

import JSON
import ImagesConvertion

using Logging

export convertImagesToLARModel

function loadConfiguration()
  """
  load parameters from JSON file
  """

  # Border dimensions are the nearest powers of two of the image sizes

  inputDirectory = "/home/danilo/Prova/IMAGES/" # Directory containing images
  outputDirectory = "/home/danilo/Prova/OUTPUT/" # Directory containing output
  bestImage = "slice.z.08.01_63.png" # Image chosen for centroids conputation
  nx = 2 # Border x
  ny = 2 # Border y
  nz = 2 # Border z
  DEBUG_LEVEL = DEBUG

  return inputDirectory, outputDirectory, bestImage, nx, ny, nz, DEBUG_LEVEL
end

function convertImagesToLARModel()
  """
  Start convertion
  """
  inputDirectory, outputDirectory, bestImage, nx, ny, nz, DEBUG_LEVEL = loadConfiguration()

  # Create output directory
  try
    mkpath(outputDirectory)
  catch
  end

  Logging.configure(level=DEBUG_LEVEL)
  ImagesConvertion.images2LARModel(nx, ny, nz, bestImage, inputDirectory, outputDirectory)
end
end
