module OtherCellArrays

using LinearAlgebra: det
import LinearAlgebra

using Numa.Helpers

export OtherCellArray
export IndexableCellArray
export OtherCellArrayFromUnaryOp
export OtherCellArrayFromElemUnaryOp
export OtherConstantCellArray
export maxsize
export maxlength

#TODO This is a temporary file in order to explore an alternative CellArray design.

"""
Abstract type representing an iterable collection of Arrays{T,N},
where each array is associated to a cell.
"""
abstract type OtherCellArray{T,N} end

Base.iterate(::OtherCellArray)::Union{Nothing,Tuple{Tuple{Array{T,N},NTuple{N,Int}},Any}} = @abstractmethod

Base.iterate(::OtherCellArray,state)::Union{Nothing,Tuple{Tuple{Array{T,N},NTuple{N,Int}},Any}} = @abstractmethod

Base.length(::OtherCellArray)::Int = @abstractmethod

maxsize(::OtherCellArray{T,N} where {T,N})::NTuple{N,Int} = @abstractmethod

"""
Abstract type representing an indexable CellArray.
By implementing a concrete IndexableCellArray, one automatically
gets a type that is also iterable
"""
abstract type OtherIndexableCellArray{T,N} <: OtherCellArray{T,N} end

Base.getindex(::OtherIndexableCellArray{T,N} where {T,N},cell::Int)::Tuple{Array{T,N},NTuple{N,Int}} = @abstractmethod

"""
Abstract type to be used for the implementation of types representing
the lazy result of applying an unary operation on a CellArray
"""
abstract type OtherCellArrayFromUnaryOp{C<:OtherCellArray,T,N} <: OtherCellArray{T,N} end

inputcellarray(::OtherCellArrayFromUnaryOp{C,T,N} where {C,T,N})::C = @abstractmethod

computesize(::OtherCellArrayFromUnaryOp, asize) = @abstractmethod

computevals!(::OtherCellArrayFromUnaryOp, a, asize, v, vsize) = @abstractmethod

"""
Like OtherCellArrayFromUnaryOp but for the particular case of element-wise operation
in the elements of the returned array
"""
abstract type OtherCellArrayFromElemUnaryOp{C,T,N} <: OtherCellArrayFromUnaryOp{C,T,N} end

"""
Abstract type to be used for the implementation of types representing
the lazy result of applying a binary operation on two CellArray objects
"""
abstract type OtherCellArrayFromBinaryOp{A<:OtherCellArray,B<:OtherCellArray,T,N} <: OtherCellArray{T,N} end

leftcellarray(::OtherCellArrayFromBinaryOp{A,B,T,N} where {A,B,T,N})::A = @abstractmethod

rightcellarray(::OtherCellArrayFromBinaryOp{A,B,T,N} where {A,B,T,N})::B = @abstractmethod

computesize(::OtherCellArrayFromBinaryOp, asize, bsize) = @abstractmethod

computevals!(::OtherCellArrayFromBinaryOp, a, asize, b, bsize, v, vsize) = @abstractmethod

"""
Like OtherCellArrayFromBinaryOp but for the particular case of element-wise operation
in the elements of the returned array
"""
abstract type OtherCellArrayFromElemBinaryOp{A,B,T,N} <: OtherCellArrayFromBinaryOp{A,B,T,N} end

# Concrete implementations

"""
Concrete implementation of CellArray, where the same array
is associated to all cells. Typically, this is useful for
discretizations with a single cell type.
"""
struct OtherConstantCellArray{T,N} <: OtherIndexableCellArray{T,N}
  array::Array{T,N}
  length::Int
end

"""
Type that stores the lazy result of evaluating the determinant
of each element in a CellArray
"""
struct OtherCellArrayFromDet{C,T,N} <: OtherCellArrayFromElemUnaryOp{C,T,N}
  a::C
end

"""
Type that stores the lazy result of evaluating the inverse of
of each element in a CellArray
"""
struct OtherCellArrayFromInv{C,T,N} <: OtherCellArrayFromElemUnaryOp{C,T,N}
  a::C
end

"""
Lazy sum of two cell arrays
"""
struct OtherCellArrayFromSum{A,B,T,N} <: OtherCellArrayFromElemBinaryOp{A,B,T,N}
  a::A
  b::B
end

"""
Lazy subtraction of two cell arrays
"""
struct OtherCellArrayFromSub{A,B,T,N} <: OtherCellArrayFromElemBinaryOp{A,B,T,N}
  a::A
  b::B
end

"""
Lazy multiplication of two cell arrays
"""
struct OtherCellArrayFromMul{A,B,T,N} <: OtherCellArrayFromElemBinaryOp{A,B,T,N}
  a::A
  b::B
end

"""
Lazy division of two cell arrays
"""
struct OtherCellArrayFromDiv{A,B,T,N} <: OtherCellArrayFromElemBinaryOp{A,B,T,N}
  a::A
  b::B
end

# Methods

# OtherCellArray

Base.eltype(::Type{C}) where C<:OtherCellArray{T,N} where {T,N} = Array{T,N}

maxsize(self::OtherCellArray,i::Int) = (s = maxsize(self); s[i])

maxlength(self::OtherCellArray) = prod(maxsize(self))

function Base.show(io::IO,self::OtherCellArray)
  for (i,(a,s)) in enumerate(self)
    v = viewtosize(a,s)
    println(io,"$i -> $v")
  end
end

function Base.:(==)(a::OtherCellArray{T,N},b::OtherCellArray{T,N}) where {T,N}
  length(a) != length(b) && return false
  maxsize(a) != maxsize(b) && return false
  if N != 1; @notimplemented end
  for ((ai,ais),(bi,bis)) in zip(a,b)
    ais != bis && return false
    for j in 1:ais[1]
      ai[j] != bi[j] && return false
    end
  end
  return true
end

function Base.:+(a::OtherCellArray{T,N},b::OtherCellArray{T,N}) where {T,N}
  OtherCellArrayFromSum{typeof(a),typeof(b),T,N}(a,b)
end

function Base.:-(a::OtherCellArray{T,N},b::OtherCellArray{T,N}) where {T,N}
  OtherCellArrayFromSub{typeof(a),typeof(b),T,N}(a,b)
end

function Base.:*(a::OtherCellArray{T,N},b::OtherCellArray{T,N}) where {T,N}
  OtherCellArrayFromMul{typeof(a),typeof(b),T,N}(a,b)
end

function Base.:/(a::OtherCellArray{T,N},b::OtherCellArray{T,N}) where {T,N}
  OtherCellArrayFromDiv{typeof(a),typeof(b),T,N}(a,b)
end

"""
Assumes that det is defined for instances of T
and that the result is Float64
"""
function LinearAlgebra.det(self::OtherCellArray{T,N}) where {T,N}
  OtherCellArrayFromDet{typeof(self),Float64,N}(self)
end

"""
Assumes that inv is defined for instances of T
"""
function LinearAlgebra.inv(self::OtherCellArray{T,N}) where {T,N}
  OtherCellArrayFromInv{typeof(self),T,N}(self)
end

# OtherIndexableCellArray

Base.iterate(self::OtherIndexableCellArray) = iterate(self,0)

function Base.iterate(self::OtherIndexableCellArray,state::Int)
  if length(self) == state
    nothing
  else
    k = state+1
    (self[k],k)
  end
end

# OtherCellArrayFromUnaryOp

Base.length(self::OtherCellArrayFromUnaryOp) = length(inputcellarray(self))

maxsize(self::OtherCellArrayFromUnaryOp) = computesize(self,maxsize(inputcellarray(self)))

@inline function Base.iterate(self::OtherCellArrayFromUnaryOp{C,T,N}) where {C,T,N}
  v = Array{T,N}(undef,maxsize(self))
  anext = iterate(inputcellarray(self))
  if anext === nothing; return nothing end
  iteratekernel(self,anext,v)
end

@inline function Base.iterate(self::OtherCellArrayFromUnaryOp,state)
  v, astate = state
  anext = iterate(inputcellarray(self),astate)
  if anext === nothing; return nothing end
  iteratekernel(self,anext,v)
end

function iteratekernel(self::OtherCellArrayFromUnaryOp,anext,v)
  (a,asize), astate = anext
  vsize = computesize(self,asize)
  computevals!(self,a,asize,v,vsize)
  state = (v, astate)
  ((v,vsize),state)
end

# OtherCellArrayFromElemUnaryOp

computesize(::OtherCellArrayFromElemUnaryOp, asize) = asize

# OtherCellArrayFromBinaryOp

function Base.length(self::OtherCellArrayFromBinaryOp)
  @assert length(rightcellarray(self)) == length(leftcellarray(self))
  length(rightcellarray(self))
end

maxsize(self::OtherCellArrayFromBinaryOp) = computesize(self,maxsize(leftcellarray(self)),maxsize(rightcellarray(self)))

@inline function Base.iterate(self::OtherCellArrayFromBinaryOp{A,B,T,N}) where {A,B,T,N}
  v = Array{T,N}(undef,maxsize(self))
  anext = iterate(leftcellarray(self))
  if anext === nothing; return nothing end
  bnext = iterate(rightcellarray(self))
  if bnext === nothing; return nothing end
  iteratekernel(self,anext,bnext,v)
end

@inline function Base.iterate(self::OtherCellArrayFromBinaryOp,state)
  v, astate, bstate = state
  anext = iterate(leftcellarray(self),astate)
  if anext === nothing; return nothing end
  bnext = iterate(rightcellarray(self),bstate)
  if bnext === nothing; return nothing end
  iteratekernel(self,anext,bnext,v)
end

function iteratekernel(self::OtherCellArrayFromBinaryOp,anext,bnext,v)
  (a,asize), astate = anext
  (b,bsize), bstate = bnext
  vsize = computesize(self,asize,bsize)
  computevals!(self,a,asize,b,bsize,v,vsize)
  state = (v, astate, bstate)
  ((v,vsize),state)
end

# OtherCellArrayFromElemBinaryOp

function computesize(::OtherCellArrayFromElemBinaryOp, asize, bsize)
  @assert asize == bsize
  asize
end

# OtherConstantCellArray

function Base.getindex(self::OtherConstantCellArray,cell::Int)
  @assert 1 <= cell
  @assert cell <= length(self)
  (self.array, size(self.array))
end

Base.length(self::OtherConstantCellArray) = self.length

maxsize(self::OtherConstantCellArray) = size(self.array)

function Base.:(==)(a::OtherConstantCellArray{T,N},b::OtherConstantCellArray{T,N}) where {T,N}
  a.array != b.array && return false
  a.length != b.length && return false
  return true
end

function Base.:+(a::OtherConstantCellArray{T,N},b::OtherConstantCellArray{T,N}) where {T,N}
  @assert size(a.array) == size(b.array)
  @assert length(a) == length(b)
  c = Array{T,N}(undef,size(a.array))
  c .= a.array .+ b.array
  OtherConstantCellArray(c,a.length)
end

function Base.:-(a::OtherConstantCellArray{T,N},b::OtherConstantCellArray{T,N}) where {T,N}
  @assert size(a.array) == size(b.array)
  @assert length(a) == length(b)
  c = Array{T,N}(undef,size(a.array))
  c .= a.array .- b.array
  OtherConstantCellArray(c,a.length)
end

function Base.:*(a::OtherConstantCellArray{T,N},b::OtherConstantCellArray{T,N}) where {T,N}
  @assert size(a.array) == size(b.array)
  @assert length(a) == length(b)
  c = Array{T,N}(undef,size(a.array))
  c .= a.array .* b.array
  OtherConstantCellArray(c,a.length)
end

function Base.:/(a::OtherConstantCellArray{T,N},b::OtherConstantCellArray{T,N}) where {T,N}
  @assert size(a.array) == size(b.array)
  @assert length(a) == length(b)
  c = Array{T,N}(undef,size(a.array))
  c .= a.array ./ b.array
  OtherConstantCellArray(c,a.length)
end

"""
Assumes that det is defined for instances of T
and that the result is Float64
"""
function LinearAlgebra.det(self::OtherConstantCellArray{T,N}) where {T,N}
  deta = Array{Float64,N}(undef,size(self.array))
  deta .= det.(self.array)
  OtherConstantCellArray(deta,self.length)
end

"""
Assumes that inv is defined for instances of T
"""
function LinearAlgebra.inv(self::OtherConstantCellArray{T,N}) where {T,N}
  deta = Array{T,N}(undef,size(self.array))
  deta .= inv.(self.array)
  OtherConstantCellArray(deta,self.length)
end

# OtherCellArrayFromDet

inputcellarray(self::OtherCellArrayFromDet) = self.a

function computevals!(::OtherCellArrayFromDet, a, asize, v, vsize)
  v .= det.(a)
end

# OtherCellArrayFromInv

inputcellarray(self::OtherCellArrayFromInv) = self.a

function computevals!(::OtherCellArrayFromInv, a, asize, v, vsize)
  v .= inv.(a)
end

# OtherCellArrayFromSum

leftcellarray(self::OtherCellArrayFromSum) = self.a

rightcellarray(self::OtherCellArrayFromSum) = self.b

function computevals!(::OtherCellArrayFromSum, a, asize, b, bsize, v, vsize)
  v .= a .+ b
end

# OtherCellArrayFromSub

leftcellarray(self::OtherCellArrayFromSub) = self.a

rightcellarray(self::OtherCellArrayFromSub) = self.b

function computevals!(::OtherCellArrayFromSub, a, asize, b, bsize, v, vsize)
  v .= a .- b
end

# OtherCellArrayFromMul

leftcellarray(self::OtherCellArrayFromMul) = self.a

rightcellarray(self::OtherCellArrayFromMul) = self.b

function computevals!(::OtherCellArrayFromMul, a, asize, b, bsize, v, vsize)
  v .= a .* b
end

# OtherCellArrayFromDiv

leftcellarray(self::OtherCellArrayFromDiv) = self.a

rightcellarray(self::OtherCellArrayFromDiv) = self.b

function computevals!(::OtherCellArrayFromDiv, a, asize, b, bsize, v, vsize)
  v .= a ./ b
end

end # module OtherCellArrays
