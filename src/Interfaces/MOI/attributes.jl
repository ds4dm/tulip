# =============================================
#   Supported attributes
# =============================================
const SUPPORTED_OPTIMIZER_ATTR = Union{
    MOI.NumberOfThreads,
    MOI.SolverName,
    MOI.Silent,
    MOI.TimeLimitSec,
}

MOI.supports(::Optimizer, ::A) where{A<:SUPPORTED_OPTIMIZER_ATTR} = true


# =============================================
#   1. Optimizer attributes
# =============================================

#
#   NumberOfThreads
#
MOI.get(m::Optimizer, ::MOI.NumberOfThreads) = m.inner.params.Threads

function MOI.set(m::Optimizer, ::MOI.NumberOfThreads, n::Int)
    # TODO: use lower-level API
    m.inner.params.Threads = n
    return nothing
end

#
#   SolverName
#
MOI.get(::Optimizer, ::MOI.SolverName) = "Tulip"

#
#   Silent
#
MOI.get(m::Optimizer, ::MOI.Silent) = m.inner.params.OutputLevel <= 0

function MOI.set(m::Optimizer, ::MOI.Silent, flag::Bool)
    m.inner.params.OutputLevel = 1 - flag
    # TODO: make a decision about LogLevel
    return nothing
end

#
#   TimeLimitSec
#
MOI.get(m::Optimizer, ::MOI.TimeLimitSec) = m.inner.params.TimeLimit

function MOI.set(m::Optimizer, ::MOI.TimeLimitSec, t)
    m.inner.params.TimeLimit = t
    return nothing
end

# =============================================
#   2. Model attributes
# =============================================
const SUPPORTED_MODEL_ATTR = Union{
    MOI.Name,
    MOI.ObjectiveSense,
    MOI.NumberOfVariables,
    MOI.ListOfVariableIndices,
    MOI.ListOfConstraintIndices,
    MOI.NumberOfConstraints,
    # ListOfConstraints,  # TODO
    MOI.ObjectiveFunctionType,
    MOI.ObjectiveValue,
    MOI.DualObjectiveValue,
    MOI.RelativeGap,
    # MOI.SolveTime,  # TODO
    MOI.SimplexIterations,
    MOI.BarrierIterations,
    MOI.RawSolver,
    # MOI.RawStatusString,  # TODO
    MOI.ResultCount,
    MOI.TerminationStatus,
    MOI.PrimalStatus,
    MOI.DualStatus
}

MOI.supports(::Optimizer, ::SUPPORTED_MODEL_ATTR) = true

#
#   ListOfVariableIndices
#
function MOI.get(m::Optimizer, ::MOI.ListOfVariableIndices)
    return collect(keys(m.var_indices))
end

#
#   Name
#
MOI.get(m::Optimizer, ::MOI.Name) = m.inner.pbdata.name

#
#   NumberOfVariables
#
MOI.get(m::Optimizer, ::MOI.NumberOfVariables) = m.inner.pbdata.nvar

#
#   ObjectiveFunctionType
#
MOI.get(
    m::Optimizer{Tv}, ::MOI.ObjectiveFunctionType
) where{Tv} = MOI.ScalarAffineFunction{Tv}

#
#   ObjectiveSense
#
function MOI.get(m::Optimizer, ::MOI.ObjectiveSense)
    m.is_feas && return MOI.FEASIBILITY_SENSE

    return m.inner.pbdata.objsense ? MOI.MIN_SENSE : MOI.MAX_SENSE
end

function MOI.set(m::Optimizer, ::MOI.ObjectiveSense, s::MOI.OptimizationSense)
    m.is_feas = (s == MOI.FEASIBILITY_SENSE)

    if s == MOI.MIN_SENSE || s == MOI.FEASIBILITY_SENSE
        m.inner.pbdata.objsense = true
    elseif s == MOI.MAX_SENSE
        m.inner.pbdata.objsense = false
    else
        error("Objetive sense not supported: $s")
    end
    
    return nothing
end

#
#   ObjectiveValue
#
function MOI.get(m::Optimizer{Tv}, attr::MOI.ObjectiveValue) where{Tv}
    MOI.check_result_index_bounds(m, attr)
    return get_attribute(m.inner, ObjectiveValue())
end

#
#   DualObjectiveValue
#
function MOI.get(m::Optimizer{Tv}, attr::MOI.DualObjectiveValue) where{Tv}
    MOI.check_result_index_bounds(m, attr)
    return get_attribute(m.inner, DualObjectiveValue())
end

#
#   RawSolver
#
MOI.get(m::Optimizer, ::MOI.RawSolver) = m.inner

#
#   RelativeGap
#
function MOI.get(m::Optimizer{Tv}, ::MOI.RelativeGap) where{Tv}
    # TODO: dispatch a function call on m.inner
    zp = m.inner.solver.primal_bound_scaled
    zd = m.inner.solver.dual_bound_scaled
    return (abs(zp - zd) / (Tv(1 // 10^6)) + abs(zd))
end

#
#   ResultCount
#
function MOI.get(m::Optimizer, ::MOI.ResultCount)
    st = MOI.get(m, MOI.TerminationStatus())

    if (st == MOI.OPTIMIZE_NOT_CALLED
        || st == MOI.OTHER_ERROR
        || st == MOI.MEMORY_LIMIT
    )
        return 0
    end
    return 1
end

#
#   SimplexIterations
#
MOI.get(::Optimizer, ::MOI.SimplexIterations) = 0

#
#   BarrierIterations
#
# TODO: use inner query
MOI.get(m::Optimizer, ::MOI.BarrierIterations) = get_attribute(m.inner, BarrierIterations())

#
#   TerminationStatus
#
# TODO: use inner query
function MOI.get(m::Optimizer, ::MOI.TerminationStatus)
    isa(m.inner.solver, Nothing) && return MOI.OPTIMIZE_NOT_CALLED

    st = m.inner.solver.solver_status
    
    return MOITerminationStatus(st)
end

#
#   PrimalStatus
#
# TODO: use inner query
function MOI.get(m::Optimizer, attr::MOI.PrimalStatus)
    attr.N == 1 || return MOI.NO_SOLUTION

    return MOISolutionStatus(m.inner.solver.primal_status)
end

#
#   DualStatus
#
# TODO: use inner query
function MOI.get(m::Optimizer, attr::MOI.DualStatus)
    attr.N == 1 || return MOI.NO_SOLUTION
    
    return MOISolutionStatus(m.inner.solver.dual_status)
end