# TODOs

## ImagesToLARModel

- Because of a bug in ImageMagick probably it would be better to create a bash script for convert dicom images to png (convert -define dcm:display-range=reset slice.0000.0002.dcm -normalize slice.0000.0002.png or convert -define dcm:display-range=reset slice.0000.0002.dcm -auto-level slice.0000.0002.png)

- Implement a distributed algorithm for model smoothing

## PngStack2Array3dJulia

- Actually if images dimensions are odd I remove one pixel; perhaps it would be better to add one instead
- Images convertion need to be parallelized

## LARUtils

## GenerateBorderMatrix

- Border Matrix Generation needs to be parallelized

## ImagesConvertion

- Every process takes a copy of the sparse  boundary matrix, try to use a shared array or something similar to reduce network communications

## Lar2Julia

- Convert all python functions inside larcc module into julia functions
- Delete all old pyplasm functions

## Model2Obj

- When creating stl files we need all cubes or only "+1" oriented faces?
- Add functions for removing double vertices and faces (it could be an iterative local removing)

## Tests

- Update all old tests (they don't work after package refactoring)
- Add new tests for:
  - PngStack2Array3dJulia
  - LARUtils
  - GenerateBorderMatrix
  - Lar2Julia
  - Model2Obj
