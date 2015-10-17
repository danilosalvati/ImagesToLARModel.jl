module LARUtils
"""
Utility functions for extracting 3d models from images
"""
export ind, invertIndex, getBases

function ind(x, y, z, nx, ny)
    """
    Transform coordinates into linearized matrix indexes
    """
    return x + (nx+1) * (y + (ny+1) * (z))
  end


function invertIndex(nx,ny,nz)
  """
  Invert indexes
  """
  nx, ny, nz = nx + 1, ny + 1, nz + 1
  function invertIndex0(offset)
      a0, b0 = trunc(offset / nx), offset % nx
      a1, b1 = trunc(a0 / ny), a0 % ny
      a2, b2 = trunc(a1 / nz), a1 % nz
      return b0, b1, b2
  end
  return invertIndex0
end


function getBases(nx, ny, nz)
  """
  Compute all LAR relations
  """

  function the3Dcell(coords)
    x,y,z = coords
    return [ind(x,y,z,nx,ny),ind(x+1,y,z,nx,ny),ind(x,y+1,z,nx,ny),ind(x,y,z+1,nx,ny),ind(x+1,y+1,z,nx,ny),
            ind(x+1,y,z+1,nx,ny),ind(x,y+1,z+1,nx,ny),ind(x+1,y+1,z+1,nx,ny)]
  end

  # Calculating vertex coordinates (nx * ny * nz)
  V = Array{Int64}[]
  for z in 0:nz
    for y in 0:ny
      for x in 0:nx
        push!(V,[x,y,z])
      end
    end
  end


  # Building CV relationship
  CV = Array{Int64}[]
  for z in 0:nz-1
    for y in 0:ny-1
      for x in 0:nx-1
        push!(CV,the3Dcell([x,y,z]))
      end
    end
  end

  # Building FV relationship
  FV = Array{Int64}[]
  v2coords = invertIndex(nx,ny,nz)

  for h in 0:(length(V)-1)
    x,y,z = v2coords(h)

    if (x < nx) && (y < ny)
      push!(FV, [h,ind(x+1,y,z,nx,ny),ind(x,y+1,z,nx,ny),ind(x+1,y+1,z,nx,ny)])
    end

    if (x < nx) && (z < nz)
      push!(FV, [h,ind(x+1,y,z,nx,ny),ind(x,y,z+1,nx,ny),ind(x+1,y,z+1,nx,ny)])
    end

    if (y < ny) && (z < nz)
      push!(FV,[h,ind(x,y+1,z,nx,ny),ind(x,y,z+1,nx,ny),ind(x,y+1,z+1,nx,ny)])
    end

  end

  # Building VV relationship
  VV = map((x)->[x], 0:length(V)-1)

  # Building EV relationship
  EV = Array{Int64}[]
  for h in 0:length(V)-1
    x,y,z = v2coords(h)
    if (x < nx)
      push!(EV, [h,ind(x+1,y,z,nx,ny)])
    end
    if (y < ny)
      push!(EV, [h,ind(x,y+1,z,nx,ny)])
    end
    if (z < nz)
      push!(EV, [h,ind(x,y,z+1,nx,ny)])
    end
  end

  # return all basis
  return V, (VV, EV, FV, CV)
end
end
