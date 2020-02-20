
struct MultiFieldCellArray{T,N,B<:Tuple} <: AbstractVector{MultiFieldArray{T,N,Array{T,N}}}
  blocks::B
  block_ids::Vector{NTuple{N,Int}}
  function MultiFieldCellArray(_blocks::Tuple,_block_ids::Vector{NTuple{N,Int}}) where N
    blocks, block_ids = _merge_repeated_blocks_mca(_blocks,_block_ids)
    @assert length(blocks) > 0
    @assert length(blocks) == length(block_ids)
    bi, = blocks
    @assert isa(bi,AbstractArray)
    @assert all( ( size(b) == size(bi) for b in blocks ) )
    @assert all( ( eltype(b) == eltype(bi) for b in blocks ) )
    A = eltype(bi)
    @assert A <: Array
    @assert ndims(A) == N
    T = eltype(A)
    B = typeof(blocks)
    new{T,N,B}(blocks,block_ids)
  end
end

function _merge_repeated_blocks_mca(blocks,coordinates::Vector{NTuple{N,Int}}) where N
  @assert length(blocks) == length(coordinates)
  s = _get_block_size(coordinates)
  ptrs = zeros(Int,s)
  _blocks = []
  _coords = NTuple{N,Int}[]
  q = 1
  for b in 1:length(blocks)
    c = coordinates[b]
    block = blocks[b]
    p = ptrs[c...]
    if p == 0
      push!(_blocks,block)
      push!(_coords,c)
      ptrs[c...] = q
      q += 1
    else
      _blocks[p] = apply(elem(+),_blocks[p],block)
    end
  end
  ( tuple(_blocks...), _coords)
end

function array_cache(a::MultiFieldCellArray{T,N}) where {T,N}
  coordinates = a.block_ids
  nblocks = length(coordinates)
  blocks = Vector{Array{T,N}}(undef,nblocks)
  b = MultiFieldArray(blocks,coordinates)
  caches = array_caches(a.blocks...)
  (b,caches)
end

function getindex!(cache,a::MultiFieldCellArray,i::Integer)
  b, caches = cache
  bis = getitems!(caches,a.blocks,i)
  for (k,bk) in enumerate(bis)
    b.blocks[k] = bk
  end
  b
end

function Base.getindex(a::MultiFieldCellArray,i::Integer)
  cache = array_cache(a)
  getindex!(cache,a,i)
end

function Base.size(a::MultiFieldCellArray) 
  bi, = a.blocks
  size(bi)
end

function reindex(a::MultiFieldCellArray,b::AbstractArray)
  f = (ai) -> reindex(ai,b)
  blocks = map(f,a.blocks)
  MultiFieldCellArray(blocks,a.block_ids)
end

function reindex(a::MultiFieldCellArray,b::IdentityVector)
  a
end

struct BlockTracker{N} <: GridapType
  blocks::Tuple
  block_ids::Vector{NTuple{N,Int}}
end

function operate(::typeof(+),a::BlockTracker)
  a
end

function operate(::typeof(-),a::BlockTracker)
  new_blocks = map(-,a.blocks)
  BlockTracker(new_blocks,a.block_ids)
end

function operate(::typeof(+),a::BlockTracker,b::BlockTracker)
  new_blocks = (a.blocks...,b.blocks...)
  new_block_ids = vcat(a.block_ids,b.block_ids)
  BlockTracker(new_blocks,new_block_ids)
end

function operate(::typeof(-),a::BlockTracker,b::BlockTracker)
  new_blocks = (a.blocks...,(-b).blocks...)
  new_block_ids = vcat(a.block_ids,b.block_ids)
  BlockTracker(new_blocks,new_block_ids)
end

