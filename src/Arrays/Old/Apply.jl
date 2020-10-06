
"""
    lazy_map(f,a::AbstractArray...) -> AbstractArray

Applies the kernel `f` to the entries of the arrays in `a` (see the definition of [`Kernel`](@ref)).

The resulting array `r` is such that `r[i]` equals to `lazy_map_kernel(f,ai...)` where `ai`
is the tuple containing the `i`-th entry of the arrays in `a` (see function
[`lazy_map_kernel`](@ref) for more details).
In other words, the resulting array is numerically equivalent to:

    map( (x...)->lazy_map_kernel(f,x...), a...)


See the [`lazy_map_kernel`](@ref) function for details.

# Examples

Using a function as kernel

```jldoctest
using Gridap.Arrays

a = collect(0:5)
b = collect(10:15)

c = lazy_map(+,a,b)

println(c)

# output
[10, 12, 14, 16, 18, 20]
```

Using a user-defined kernel

```jldoctest
using Gridap.Arrays
import Gridap.Arrays: lazy_map_kernel!

a = collect(0:5)
b = collect(10:15)

struct MySum <: Kernel end

lazy_map_kernel!(cache,::MySum,x,y) = x + y

k = MySum()

c = lazy_map(k,a,b)

println(c)

# output
[10, 12, 14, 16, 18, 20]
```

"""
function lazy_map(f,a::AbstractArray...)
  s = common_size(a...)
  lazy_map(Fill(f,s...),a...)
end

"""
    lazy_map(::Type{T},f,a::AbstractArray...) where T

Like [`lazy_map(f,a::AbstractArray...)`](@ref), but the user provides the element type
of the resulting array in order to circumvent type inference.
"""
function lazy_map(::Type{T},f,a::AbstractArray...) where T
  s = common_size(a...)
  lazy_map(T,Fill(f,s...),a...)
end

"""
    lazy_map(f::AbstractArray,a::AbstractArray...) -> AbstractArray
Applies the kernels in the array of kernels `f` to the entries in the arrays in `a`.

The resulting array has the same entries as the one obtained with:

    map( lazy_map_kernel, f, a...)

See the [`lazy_map_kernel`](@ref) function for details.

# Example

"Evaluating" an array of functions

```jldoctest
using Gridap.Arrays

f = [+,-,max,min]
a = [1,2,3,4]
b = [4,3,2,1]

c = lazy_map(f,a,b)

println(c)

# output
[5, -1, 3, 1]
```
"""
function lazy_map(f::AbstractArray,a::AbstractArray...)
  AppliedArray(f,a...)
end

"""
    lazy_map(::Type{T},f::AbstractArray,a::AbstractArray...) where T

Like [`lazy_map(f::AbstractArray,a::AbstractArray...)`](@ref), but the user provides the element type
of the resulting array in order to circumvent type inference.
"""
function lazy_map(::Type{T},f::AbstractArray,a::AbstractArray...) where T
  AppliedArray(T,f,a...)
end

"""
    lazy_map_all(f::Tuple,a::AbstractArray...) -> Tuple

Numerically equivalent to

    tuple( ( lazy_map(fi, a...) for fi in f)... )

# Examples

```jldoctest
using Gridap.Arrays

a = [1,2,3,4]
b = [4,3,2,1]

c = lazy_map_all( (+,-), a, b)

# Equivalent to
# c = ( lazy_map(+,a,b), lazy_map(-,a,b) )

println(c)

# output
([5, 5, 5, 5], [-3, -1, 1, 3])

```
"""
function lazy_map_all(f::Tuple,a::AbstractArray...)
  _lazy_map_several(a,f...)
end

function _lazy_map_several(a,f,g...)
  fa = lazy_map(f,a...)
  ga = _lazy_map_several(a,g...)
  (fa,ga...)
end

function _lazy_map_several(a,f)
  fa = lazy_map(f,a...)
  (fa,)
end

# Helpers

struct AppliedArray{T,N,F,G} <: AbstractArray{T,N}
  g::G
  f::F
  function AppliedArray(::Type{T},g::AbstractArray,f::AbstractArray...) where T
    G = typeof(g)
    F = typeof(f)
    f1, = f
    new{T,ndims(f1),F,G}(g,f)
  end
end

function AppliedArray(g::AbstractArray,f::AbstractArray...)
  gi = testitem(g) #Assumes that all kernels return the same type
  fi = testitems(f...)
  T = typeof(kernel_testitem(gi,fi...))
  AppliedArray(T,g,f...)
end

function uses_hash(::Type{<:AppliedArray})
  Val(true)
end

function array_cache(hash::Dict,a::AppliedArray)
    id = objectid(a)
    _cache = _array_cache(hash,a)
    if haskey(hash,id)
      cache = _get_stored_cache(_cache,hash,id)
    else
      cache = _cache
      hash[id] = cache
    end
    cache
end

#TODO
@static if VERSION >= v"1.1"
  @noinline function _get_stored_cache(cache::T,hash,id) where T
    c::T = hash[id]
    c
  end
else
  @noinline function _get_stored_cache(cache::T,hash,id) where T
    hash[id]
  end
end

function _array_cache(hash,a::AppliedArray)
  cg = array_cache(hash,a.g)
  gi = testitem(a.g)
  fi = testitems(a.f...)
  @notimplementedif ! all( map(isconcretetype,map(eltype,a.f)) )
  if ! (eltype(a.g)<:Function)
    @notimplementedif ! isconcretetype(eltype(a.g))
  end
  cf = map(fi -> array_cache(hash,fi),a.f...)
  # cf = array_caches(hash,a.f...)
  cgi = kernel_cache(gi,fi...)
  ai = kernel_testitem!(cgi,gi,fi...)
  i = -testitem(eachindex(a))
  e = Evaluation((i,),ai)
  c = (cg, cgi, cf)
  (c,e)
end

function testitem(a::AppliedArray)
  cg = array_cache(a.g)
  gi = testitem(a.g)
  fi = testitems(a.f...)
  kernel_testitem(gi,fi...)
end

function getindex!(cache,a::AppliedArray,i::Integer...)
  li = LinearIndices(a)
  getindex!(cache,a,li[i...])
end

function getindex!(cache,a::AppliedArray,i::Integer)
  _cached_getindex!(cache,a,(i,))
end

function getindex!(cache,a::AppliedArray,i::CartesianIndex)
  _cached_getindex!(cache,a,Tuple(i))
end

function _cached_getindex!(cache,a::AppliedArray,i::Tuple)
  c, e = cache
  v = e.fx
  if e.x != i
    v = _getindex!(c,a,i...)
    e.x = i
    e.fx = v
  end
   v
end

function _getindex!(cache,a::AppliedArray,i...)
  cg, cgi, cf = cache
  gi = getindex!(cg,a.g,i...)
  fi = map((ci,ai) -> getindex!(ci,ai,i...),cf,a.f)
  # fi = getitems!(cf,a.f,i...)
  vi = lazy_map_kernel!(cgi,gi,fi...)
  vi
end

function Base.getindex(a::AppliedArray,i...)
  ca = array_cache(a)
  getindex!(ca,a,i...)
end

function Base.IndexStyle(
  ::Type{AppliedArray{T,N,F,G}}) where {T,N,F,G}
  common_index_style(F)
end

function Base.size(a::AppliedArray)
  f, = a.f
  size(f)
end

function common_size(a::AbstractArray...)
  a1, = a
  c = all([length(a1) == length(ai) for ai in a])
  if !c
    error("Array sizes $(map(size,a)) are not compatible.")
  end
  l = length(a1)
  (l,)
end

#TODO not sure what to do with shape and index-style
function common_index_style(::Type{<:Tuple})
  IndexLinear()
end

mutable struct Evaluation{X,F} <: GridapType
  x::X
  fx::F
  function Evaluation(x::X,fx::F) where {X,F}
    new{X,F}(x,fx)
  end
end

# Particular implementations for Fill

function lazy_map(f::Fill,a::Fill...)
  ai = getvalues(a...)
  r = lazy_map_kernel(f.value,ai...)
  s = common_size(f,a...)
  Fill(r,s)
end

function lazy_map(::Type{T},f::Fill,a::Fill...) where T
  lazy_map(f,a...)
end

function getvalues(a::Fill,b::Fill...)
  ai = a.value
  bi = getvalues(b...)
  (ai,bi...)
end

function getvalues(a::Fill)
  ai = a.value
  (ai,)
end

function Base.sum(a::AppliedArray)
  cache = array_cache(a)
  _sum_array_cache(cache,a)
end

function _sum_array_cache(cache,a)
  r = zero(eltype(a))
  for i in eachindex(a)
    ai = getindex!(cache,a,i)
    r += ai
  end
  r
end

# TODO Think about iteration and sub-iteration

# Helper type to test caching of intermediate results

struct ArrayWithCounter{T,N,A,C} <: AbstractArray{T,N}
  array::A
  counter::C
  function ArrayWithCounter(a::AbstractArray{T,N}) where {T,N}
    c = zeros(Int,size(a))
    c[:] .= 0
    new{T,N,typeof(a),typeof(c)}(a,c)
  end
end

Base.size(a::ArrayWithCounter) = size(a.array)

function Base.getindex(a::ArrayWithCounter,i::Integer...)
  a.counter[i...] += 1
  a.array[i...]
end

Base.IndexStyle(::Type{<:ArrayWithCounter{T,N,A}}) where {T,A,N} = IndexStyle(A)

function reset_counter!(a::ArrayWithCounter)
  a.counter[:] .= 0
end
