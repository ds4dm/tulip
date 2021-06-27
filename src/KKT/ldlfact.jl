using LDLFactorizations
const LDLF = LDLFactorizations

"""
    LDLFactBackend

LDLFactorizations backend for solving linear systems.
"""
struct LDLFactBackend <: AbstractKKTBackend end

mutable struct LDLFactSolver{T,S} <: AbstractKKTSolver{T}
    # Problem data
    m::Int
    n::Int
    A::SparseMatrixCSC{T,Int}

    # Workspace
    θ::Vector{T}                 # Diagonal scaling
    regP::Vector{T}              # Primal regularization
    regD::Vector{T}              # Dual regularization
    K::SparseMatrixCSC{T,Int}    # KKT matrix
    F::LDLF.LDLFactorization{T}  # Factorization
    ξ::Vector{T}                 # RHS of KKT system
end

backend(::LDLFactSolver) = "LDLFactorizations"
linear_system(::LDLFactSolver) = "Augmented system (K2)"

setup(A, system, backend::LDLFactBackend) = setup(sparse(A), system, backend)

function setup(A::SparseMatrixCSC{T,Int}, ::K2, ::LDLFactBackend) where{T}
    m, n = size(A)

    θ = ones(T, n)
    regP = ones(T, n)
    regD = ones(T, m)
    ξ = zeros(T, m+n)

    K = [
        spdiagm(0 => -θ)  A';
        spzeros(T, m, n) spdiagm(0 => ones(T, m))
    ]

    # TODO: Symbolic factorization only
    F = LDLF.ldl_analyze(Symmetric(K))

    return LDLFactSolver{T,K2}(m, n, A, θ, regP, regD, K, F, ξ)
end

function update!(kkt::LDLFactSolver{T,K2}, θ, regP, regD) where{T}
    m, n = kkt.m, kkt.n

    # Sanity checks
    length(θ)  == n || throw(DimensionMismatch(
        "length(θ)=$(length(θ)) but KKT solver has n=$n."
    ))
    length(regP) == n || throw(DimensionMismatch(
        "length(regP)=$(length(regP)) but KKT solver has n=$n"
    ))
    length(regD) == m || throw(DimensionMismatch(
        "length(regD)=$(length(regD)) but KKT solver has m=$m"
    ))

    copyto!(kkt.θ, θ)
    copyto!(kkt.regP, regP)
    copyto!(kkt.regD, regD)

    # Update KKT matrix
    # K is stored as upper-triangular, and only its diagonal is changed
    @inbounds for j in 1:kkt.n
        k = kkt.K.colptr[1+j] - 1
        kkt.K.nzval[k] = -kkt.θ[j] - regP[j]
    end
    @inbounds for i in 1:kkt.m
        k = kkt.K.colptr[1+kkt.n+i] - 1
        kkt.K.nzval[k] = regD[i]
    end

    # Update factorization
    try
        LDLF.ldl_factorize!(Symmetric(kkt.K), kkt.F)
    catch err
        isa(err, LDLF.SQDException) && throw(PosDefException(-1))
        rethrow(err)
    end

    return nothing
end

function solve!(dx, dy, kkt::LDLFactSolver{T,K2}, ξp, ξd) where{T}
    m, n = kkt.m, kkt.n

    # Setup right-hand side
    @views copyto!(kkt.ξ[1:n], ξd)
    @views copyto!(kkt.ξ[(n+1):end], ξp)

    # Solve augmented system
    # CHOLMOD doesn't have in-place solve, so this line will allocate
    LDLF.ldiv!(kkt.F, kkt.ξ)

    # Recover dx, dy
    @views copyto!(dx, kkt.ξ[1:n])
    @views copyto!(dy, kkt.ξ[(n+1):end])

    # TODO: iterative refinement
    return nothing
end
