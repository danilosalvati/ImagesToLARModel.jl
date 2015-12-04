# TODOs

## ImagesToLARModel

- Make images conversion optional 
- Add interfaces for other file types

## PngStack2Array3dJulia

- Actually if images dimensions are odd I remove one pixel; perhaps it would be better to add one instead
- Images conversion need to be parallelized
- Resolve this for Julia 0.4 WARNING: imwrite(img,filename; kwargs...) is deprecated, use save(filename,img; kwargs...) instead.

## LARUtils

## GenerateBorderMatrix

- Border Matrix Generation should be parallelized

## ImagesConversion

- I need a check for non-existing best images
- Every process takes a copy of the sparse  boundary matrix, try to use a shared array or something similar to reduce network communications
- Use a parameter for controlling number of smoothing iterations
- Use a parameter for image filtering
- Study Requires.jl and see if we can use a lazy load for python libraries

## Lar2Julia

- Convert all python functions inside larcc module into julia functions
- Delete all old pyplasm functions

## Model2Obj

## Smoother

## Tests

- Update all old tests (they don't work after package refactoring)
- Add new tests for:
  - PngStack2Array3dJulia
  - LARUtils
  - GenerateBorderMatrix
  - Lar2Julia
  - Model2Obj

## Documentation

- Update architecture schema with new modules and functions
- Add documentation for Model2Obj