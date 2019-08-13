# =========================
#       ADD VARIABLES
# =========================

# Add a single variable

"""
    add_variable!(m::Model, name, obj, lb, ub, rowids, rowvals)

Add one scalar variable to the model.
"""
function add_variable!(
    m::Model{Tv},
    name::String,
    obj::Tv, bt::BoundType, lb::Tv, ub::Tv,
    rowids::Vector{ConstrId},
    rowvals::Vector{Tv}
) where{Tv<:Real}

    # =================
    #   Sanity checks
    # =================
    # TODO: check inputs, check bounds
    # Q: when should bounds be checked?
    _check_bounds(bt, lb, ub) || error("Invalid bounds for $bt: [$lb, $ub].")

    length(rowids) == length(rowvals) || error(
        "rowids has length $(length(rowids)) but rowvals has length $(length(rowvals))"
    )

    # Check that all constraints do exist
    for rowid in rowids
        haskey(m.pbdata_raw.constrs, rowid) || error("Constraint $(rowid.uuid) not in model.")
    end


    # ==========================
    #   Create Variable object
    # ==========================
    vidx = new_variable_index!(m.pbdata_raw)
    var = Variable{Tv}(vidx, name, obj, bt, lb, ub)

    # Add constraint to model
    add_variable!(m.pbdata_raw, var)


    # ====================
    #   Set coefficients
    # ====================
    for (rowid, val) in zip(rowids, rowvals)
        set_coeff!(m.pbdata_raw, vidx, rowid, val)
    end
    
    return vidx
end

add_variable!(
    m::Model{Tv},
    name::String, obj::Real,
    bt::BoundType, lb::Real, ub::Real,
    rowids::Vector{ConstrId},
    rowvals::Vector{T}
) where{Tv<:Real, T<:Real} = add_variable!(m, name,
    Tv(obj), bt, Tv(lb), Tv(ub), rowids, Tv.(rowvals)
)


add_variable!(m::Model{Tv},
    name::String,
    obj::Real,
    bt::BoundType, lb::Real, ub::Real
) where{Tv<:Real} = add_variable!(m, name, obj, bt, lb, ub, ConstrId[], Tv[])

add_variable!(m::Model{Tv}) where{Tv<:Real} = add_variable!(m,
    "",
    zero(Tv),
    TLP_LO, zero(Tv), Tv(Inf),
    ConstrId[], Tv[]
)

# TODO: Add multiple variables


# ===============================
#       QUERY VARIABLE INFO
# ===============================

get_num_var(m::Model) = get_num_var(m.pbdata_raw)

get_var_name(m::Model, vid::VarId) = get_name(m.pbdata_raw.vars[vid])

get_var_bounds(m::Model, vid::VarId) = get_bounds(m.pbdata_raw.vars[vid])
