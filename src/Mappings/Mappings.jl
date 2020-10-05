module Mappings

using Gridap.Helpers
using Gridap.Inference
using Gridap.Arrays
using Gridap.Algebra: mul!
using FillArrays
using Test

import Gridap.Inference: return_type

# Mapping interface

export Mapping
export return_cache
export evaluate!
export evaluate
export return_type
export test_mapping

import Gridap.Arrays: testitem
import Gridap.Arrays: getindex!
import Gridap.Arrays: uses_hash
import Gridap.Arrays: IndexStyle

# MappedArray

export MappedArray

export apply
export test_mapped_array
# import Gridap.Arrays: apply
import Gridap.Arrays: array_cache

export BroadcastMapping
export OperationMapping
export Operation
export operation

# Field

using Gridap.TensorValues

using ForwardDiff

import LinearAlgebra: det, inv, transpose
import Base: +, -, *, /
import LinearAlgebra: ⋅

import Base: promote_type
using LinearAlgebra: mul!, Transpose

export Field
export GenericField
export FieldGradient
export FieldHessian
export ConstantField
export FunctionField
export BroadcastField
export ZeroField
export MockField
export Point

export TransposeFieldVector
export BroadcastOpFieldArray
export CompositionFieldArrayField
export DotOpFieldVectors

export evaluate_gradient!
export return_gradient_type
export return_gradient_cache
export evaluate_hessian!
export return_hessian_cache

export gradient
export ∇
export hessian

export test_field
export test_field_array
export test_operation_field_array
export test_broadcast_field_array

export mock_field

export linear_combination
export integrate

export MatMul
export Integrate

# export MockBasis
# export LinearCombinationField
# export OtherMockField
# export OtherMockBasis

# export GenericFieldArray

# export FieldHessian
# export FieldGradientArray
# export FieldHessianArray


# # export gradients

# export field_composition
# export field_array_composition

# export mock_field

include("MappingInterfaces.jl")

include("MappedArrays.jl")

include("FieldsInterfaces.jl")

include("FieldArrays.jl")

include("ApplyOptimizations.jl")

include("MockFields.jl")

include("AutoDiff.jl")

include("ArraysMappings.jl")

# include("FunctionMappings.jl")

# include("AlgebraMappings.jl")

# include("MappingArrays.jl")

# include("ConstantMappings.jl")

# @santiagobadia : To be decided what to do here
# include("MappingGradients.jl")

end
