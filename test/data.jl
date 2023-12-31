CELL_NAMES = ["TATA", "GATA", "CATA"]
GENE_NAMES = ["RSPO3", "FOXA1", "WNT6", "TNNI1"]
MARKER_GENES_BY_DEPTH =
    [[true, false, true, false], [false, true, false, true], [false, false, true, true], [true, true, false, false]]
UMIS_BY_DEPTH =
    [[0 1 2 3; 1 2 3 0; 2 3 0 1], [1 2 3 0; 2 3 0 1; 3 0 1 2], [2 3 0 1; 3 0 1 2; 0 1 2 3], [3 0 1 2; 0 1 2 3; 1 2 3 0]]

function test_missing_scalar(daf::DafReader, depth::Int)::Nothing
    if depth > 3
        return nothing
    end

    if daf isa DafWriter
        nested_test("read_only") do
            test_missing_scalar(read_only(daf), depth)
            return nothing
        end
    end

    nested_test("has_scalar") do
        @test !has_scalar(daf, "depth")
    end

    nested_test("scalar_names") do
        @test isempty(scalar_names(daf))
    end

    nested_test("get_scalar") do
        nested_test("()") do
            @test_throws dedent("""
                missing scalar: depth
                in the daf data: $(daf.name)
            """) get_scalar(daf, "depth")
        end

        nested_test("default") do
            nested_test("missing") do
                @test get_scalar(daf, "depth"; default = nothing) == nothing
            end

            nested_test("scalar") do
                @test get_scalar(daf, "depth"; default = -2) == -2
            end
        end
    end

    if !(daf isa DafWriter)
        return nothing
    end

    nested_test("delete_scalar!") do
        nested_test("()") do
            @test_throws dedent("""
                missing scalar: depth
                in the daf data: $(daf.name)
            """) delete_scalar!(daf, "depth")
        end

        nested_test("must_exist") do
            nested_test("true") do
                @test_throws dedent("""
                    missing scalar: depth
                    in the daf data: $(daf.name)
                """) delete_scalar!(daf, "depth"; must_exist = true)
            end

            nested_test("false") do
                @test delete_scalar!(daf, "depth"; must_exist = false) == nothing
            end
        end
    end

    nested_test("set_scalar!") do
        @test set_scalar!(daf, "depth", depth + 1) == nothing
        nested_test("created") do
            test_existing_scalar(daf, depth + 1)
            return nothing
        end
    end
end

function test_existing_scalar(daf::DafReader, depth::Int)::Nothing
    if daf isa DafWriter
        nested_test("read_only") do
            test_existing_scalar(read_only(daf), depth)
            return nothing
        end
    end

    if depth > 3
        return nothing
    end

    nested_test("has_scalar") do
        @test has_scalar(daf, "depth")
    end

    nested_test("scalar_names") do
        @test scalar_names(daf) == Set(["depth"])
    end

    nested_test("get_scalar") do
        nested_test("()") do
            @test get_scalar(daf, "depth") == depth
        end

        nested_test("default") do
            @test get_scalar(daf, "depth"; default = -2) == depth
        end
    end

    if !(daf isa DafWriter)
        return nothing
    end

    nested_test("delete_scalar!") do
        nested_test("()") do
            @test delete_scalar!(daf, "depth") == nothing
            nested_test("deleted") do
                test_missing_scalar(daf, depth + 1)
                return nothing
            end
        end

        nested_test("must_exist") do
            nested_test("true") do
                @test delete_scalar!(daf, "depth"; must_exist = true) == nothing
                nested_test("deleted") do
                    test_missing_scalar(daf, depth + 1)
                    return nothing
                end
            end

            nested_test("false") do
                @test delete_scalar!(daf, "depth"; must_exist = false) == nothing
                nested_test("deleted") do
                    test_missing_scalar(daf, depth + 1)
                    return nothing
                end
            end
        end
    end

    nested_test("set_scalar!") do
        nested_test("()") do
            @test_throws dedent("""
                existing scalar: depth
                in the daf data: $(daf.name)
            """) set_scalar!(daf, "depth", -1)
        end

        nested_test("overwrite") do
            nested_test("false") do
                @test_throws dedent("""
                    existing scalar: depth
                    in the daf data: $(daf.name)
                """) set_scalar!(daf, "depth", -1; overwrite = false)
            end

            nested_test("true") do
                @test set_scalar!(daf, "depth", depth + 1; overwrite = true) == nothing
                nested_test("overwritten") do
                    test_existing_scalar(daf, depth + 1)
                    return nothing
                end
            end
        end
    end
end

function test_missing_axis(daf::DafReader, depth::Int)::Nothing
    if depth > 3
        return nothing  # untested
    end

    if daf isa DafWriter
        nested_test("read_only") do
            test_missing_axis(read_only(daf), depth)
            return nothing
        end
    end

    nested_test("has_axis") do
        @test !has_axis(daf, "gene")
    end

    nested_test("axis_length") do
        @test_throws dedent("""
            missing axis: gene
            in the daf data: $(daf.name)
        """) axis_length(daf, "gene")
    end

    nested_test("axis_names") do
        @test isempty(axis_names(daf))
    end

    nested_test("vector_names") do
        @test_throws dedent("""
            missing axis: gene
            in the daf data: $(daf.name)
        """) vector_names(daf, "gene")
    end

    nested_test("get_axis") do
        nested_test("()") do
            @test_throws dedent("""
                missing axis: gene
                in the daf data: $(daf.name)
            """) get_axis(daf, "gene")
        end

        nested_test("default") do
            nested_test("undef") do
                @test_throws dedent("""
                    missing axis: gene
                    in the daf data: $(daf.name)
                """) get_axis(daf, "gene"; default = undef)
            end

            nested_test("nothing") do
                @test get_axis(daf, "gene"; default = nothing) == nothing
            end
        end
    end

    if !(daf isa DafWriter)
        return nothing
    end

    nested_test("delete_axis") do
        nested_test("()") do
            @test_throws dedent("""
                missing axis: gene
                in the daf data: $(daf.name)
            """) delete_axis!(daf, "gene")
        end

        nested_test("must_exist") do
            nested_test("true") do
                @test_throws dedent("""
                    missing axis: gene
                    in the daf data: $(daf.name)
                """) delete_axis!(daf, "gene"; must_exist = true)
            end

            nested_test("false") do
                @test delete_axis!(daf, "gene"; must_exist = false) == nothing
            end
        end
    end

    nested_test("add_axis") do
        nested_test("unique") do
            @test add_axis!(daf, "gene", GENE_NAMES) == nothing
            nested_test("created") do
                test_existing_axis(daf, depth + 1)
                return nothing
            end
        end

        nested_test("duplicated") do
            @test_throws dedent("""
                non-unique entries for new axis: gene
                in the daf data: $(daf.name)
            """) add_axis!(daf, "gene", ["FOXA1", "BATF3", "CATD2", "BATF3"])
        end
    end
end

function test_existing_axis(daf::DafReader, depth::Int)::Nothing
    if depth > 3
        return nothing
    end

    if daf isa DafWriter
        nested_test("read_only") do
            test_existing_axis(read_only(daf), depth)
            return nothing
        end
    end

    nested_test("has_axis") do
        @test has_axis(daf, "gene")
    end

    nested_test("axis_length") do
        @test axis_length(daf, "gene") == length(GENE_NAMES)
    end

    nested_test("vector_names") do
        @test isempty(vector_names(daf, "gene"))
    end

    nested_test("axis_names") do
        @test axis_names(daf) == Set(["gene"])
    end

    nested_test("get_axis") do
        @test get_axis(daf, "gene") == GENE_NAMES
    end

    nested_test("name") do
        @test get_vector(daf, "gene", "name") == GENE_NAMES
    end

    if !(daf isa DafWriter)
        return nothing
    end

    nested_test("delete_axis!") do
        nested_test("()") do
            @test delete_axis!(daf, "gene") == nothing
            nested_test("deleted") do
                test_missing_axis(daf, depth + 1)
                return nothing
            end
        end

        nested_test("must_exist") do
            nested_test("true") do
                @test delete_axis!(daf, "gene"; must_exist = true) == nothing
                nested_test("deleted") do
                    test_missing_axis(daf, depth + 1)
                    return nothing
                end
            end

            nested_test("false") do
                @test delete_axis!(daf, "gene"; must_exist = false) == nothing
                nested_test("deleted") do
                    test_missing_axis(daf, depth + 1)
                    return nothing
                end
            end
        end
    end

    nested_test("add_axis!") do
        @test_throws dedent("""
            existing axis: gene
            in the daf data: $(daf.name)
        """) add_axis!(daf, "gene", ["FOXA1", "CATD2", "BATF3"])
    end
end

function test_missing_vector_axis(daf::DafReader, depth::Int)::Nothing
    if depth > 3
        return nothing
    end

    if daf isa DafWriter
        nested_test("read_only") do
            test_missing_vector_axis(read_only(daf), depth)
            return nothing
        end
    end

    nested_test("has_vector") do
        @test_throws dedent("""
            missing axis: gene
            in the daf data: $(daf.name)
        """) has_vector(daf, "gene", "marker")
    end

    nested_test("vector_names") do
        @test_throws dedent("""
            missing axis: gene
            in the daf data: $(daf.name)
        """) vector_names(daf, "gene")
    end

    nested_test("get_vector") do
        @test_throws dedent("""
            missing axis: gene
            in the daf data: $(daf.name)
        """) get_vector(daf, "gene", "marker")
    end

    if !(daf isa DafWriter)
        return nothing
    end

    nested_test("delete_vector") do
        nested_test("()") do
            @test_throws dedent("""
                missing axis: gene
                in the daf data: $(daf.name)
            """) delete_vector!(daf, "gene", "marker")
        end

        nested_test("must_exist") do
            nested_test("true") do
                @test_throws dedent("""
                    missing axis: gene
                    in the daf data: $(daf.name)
                """) delete_vector!(daf, "gene", "marker"; must_exist = true)
            end

            nested_test("false") do
                @test_throws dedent("""
                    missing axis: gene
                    in the daf data: $(daf.name)
                """) delete_vector!(daf, "gene", "marker"; must_exist = false)
            end
        end
    end

    nested_test("set_vector!") do
        nested_test("()") do
            @test_throws dedent("""
                missing axis: gene
                in the daf data: $(daf.name)
            """) set_vector!(daf, "gene", "marker", MARKER_GENES_BY_DEPTH[depth])
        end

        nested_test("overwrite") do
            nested_test("true") do
                @test_throws dedent("""
                    missing axis: gene
                    in the daf data: $(daf.name)
                """) set_vector!(daf, "gene", "marker", MARKER_GENES_BY_DEPTH[depth]; overwrite = false)
            end

            nested_test("false") do
                @test_throws dedent("""
                    missing axis: gene
                    in the daf data: $(daf.name)
                """) set_vector!(daf, "gene", "marker", MARKER_GENES_BY_DEPTH[depth]; overwrite = true)
            end
        end
    end
end

function test_missing_vector(daf::DafReader, depth::Int)::Nothing
    if depth > 3
        return nothing
    end

    if daf isa DafWriter
        nested_test("read_only") do
            test_missing_vector(read_only(daf), depth)
            return nothing
        end
    end

    nested_test("has_vector") do
        @test !has_vector(daf, "gene", "marker")
    end

    nested_test("vector_names") do
        @test isempty(vector_names(daf, "gene"))
    end

    nested_test("get_vector") do
        nested_test("()") do
            @test_throws dedent("""
                missing vector: marker
                for the axis: gene
                in the daf data: $(daf.name)
            """) get_vector(daf, "gene", "marker")
        end

        nested_test("default") do
            nested_test("undef") do
                @test_throws dedent("""
                    missing vector: marker
                    for the axis: gene
                    in the daf data: $(daf.name)
                """) get_vector(daf, "gene", "marker"; default = undef)
            end

            nested_test("nothing") do
                @test get_vector(daf, "gene", "marker"; default = nothing) == nothing
            end

            nested_test("scalar") do
                @test get_vector(daf, "gene", "marker"; default = 1) == [1, 1, 1, 1]
                @test dimnames(get_vector(daf, "gene", "marker"; default = 1)) == ["gene"]
                @test names(get_vector(daf, "gene", "marker"; default = 1)) == [GENE_NAMES]
            end

            nested_test("vector") do
                @test get_vector(daf, "gene", "marker"; default = [true, true, false, false]) ==
                      [true, true, false, false]
                @test dimnames(get_vector(daf, "gene", "marker"; default = [true, true, false, false])) == ["gene"]
                @test names(get_vector(daf, "gene", "marker"; default = [true, true, false, false])) == [GENE_NAMES]
            end

            nested_test("named") do
                nested_test("()") do
                    @test get_vector(
                        daf,
                        "gene",
                        "marker";
                        default = NamedArray([true, true, false, false]; names = (GENE_NAMES,), dimnames = ("gene",)),
                    ) == [true, true, false, false]
                    @test dimnames(
                        get_vector(
                            daf,
                            "gene",
                            "marker";
                            default = NamedArray(
                                [true, true, false, false];
                                names = (GENE_NAMES,),
                                dimnames = ("gene",),
                            ),
                        ),
                    ) == ["gene"]
                    @test names(
                        get_vector(
                            daf,
                            "gene",
                            "marker";
                            default = NamedArray(
                                [true, true, false, false];
                                names = (GENE_NAMES,),
                                dimnames = ("gene",),
                            ),
                        ),
                    ) == [GENE_NAMES]
                end

                nested_test("!dim") do
                    @test_throws dedent("""
                        default dim name: A
                        is different from the axis: gene
                        in the daf data: $(daf.name)
                    """) get_vector(
                        daf,
                        "gene",
                        "marker",
                        default = NamedArray([true, true, false, false]; names = (GENE_NAMES,)),
                    )
                end

                nested_test("!names") do
                    @test_throws dedent("""
                        entry names of the: default
                        mismatch the entry names of the axis: gene
                        in the daf data: $(daf.name)
                    """) get_vector(
                        daf,
                        "gene",
                        "marker";
                        default = NamedArray(
                            MARKER_GENES_BY_DEPTH[depth];
                            names = (["A", "B", "C", "D"],),
                            dimnames = ("gene",),
                        ),
                    ) == nothing
                end
            end
        end
    end

    if !(daf isa DafWriter)
        return nothing
    end

    nested_test("delete_vector") do
        nested_test("()") do
            @test_throws dedent("""
                missing vector: marker
                for the axis: gene
                in the daf data: $(daf.name)
            """) delete_vector!(daf, "gene", "marker")
        end

        nested_test("must_exist") do
            nested_test("true") do
                @test_throws dedent("""
                    missing vector: marker
                    for the axis: gene
                    in the daf data: $(daf.name)
                """) delete_vector!(daf, "gene", "marker"; must_exist = true)
            end

            nested_test("false") do
                @test delete_vector!(daf, "gene", "marker"; must_exist = false) == nothing
            end
        end
    end

    nested_test("set_vector!") do
        nested_test("scalar") do
            @test set_vector!(daf, "gene", "marker", 1.0) == nothing
            @test get_vector(daf, "gene", "marker") == [1.0, 1.0, 1.0, 1.0]
        end

        nested_test("vector") do
            nested_test("()") do
                @test set_vector!(daf, "gene", "marker", MARKER_GENES_BY_DEPTH[depth]) == nothing
                test_existing_vector(daf, depth + 1)
                return nothing
            end

            nested_test("name") do
                @test_throws dedent("""
                    setting the reserved vector: name
                    for the axis: gene
                    in the daf data: $(daf.name)
                """) set_vector!(daf, "gene", "name", 1)
            end

            nested_test("!size") do
                @test_throws dedent("""
                    vector length: 3
                    is different from the length: 4
                    of the axis: gene
                    in the daf data: $(daf.name)
                """) set_vector!(daf, "gene", "marker", [true, true, true])
            end

            nested_test("named") do
                nested_test("()") do
                    @test set_vector!(
                        daf,
                        "gene",
                        "marker",
                        NamedArray(MARKER_GENES_BY_DEPTH[depth]; names = (GENE_NAMES,), dimnames = ("gene",)),
                    ) == nothing
                    test_existing_vector(daf, depth + 1)
                    return nothing
                end

                nested_test("!dim") do
                    @test_throws dedent("""
                        vector dim name: A
                        is different from the axis: gene
                        in the daf data: $(daf.name)
                    """) set_vector!(
                        daf,
                        "gene",
                        "marker",
                        NamedArray(MARKER_GENES_BY_DEPTH[depth]; names = (GENE_NAMES,)),
                    )
                end

                nested_test("!names") do
                    @test_throws dedent("""
                        entry names of the: vector
                        mismatch the entry names of the axis: gene
                        in the daf data: $(daf.name)
                    """) set_vector!(
                        daf,
                        "gene",
                        "marker",
                        NamedArray(MARKER_GENES_BY_DEPTH[depth]; names = (["A", "B", "C", "D"],), dimnames = ("gene",)),
                    ) == nothing
                end
            end
        end
    end

    nested_test("empty_vector!") do
        nested_test("dense") do
            @test empty_dense_vector!(daf, "gene", "marker", Bool) do empty
                empty .= MARKER_GENES_BY_DEPTH[depth]
                return 7
            end == 7
            test_existing_vector(daf, depth + 1)
            return nothing
        end

        nested_test("sparse") do
            @test empty_sparse_vector!(
                daf,
                "gene",
                "marker",
                Bool,
                sum(MARKER_GENES_BY_DEPTH[depth]),
                Int32,
            ) do empty
                sparse = SparseVector(MARKER_GENES_BY_DEPTH[depth])
                empty.array.nzind .= sparse.nzind
                empty.array.nzval .= sparse.nzval
                return 7
            end == 7
            test_existing_vector(daf, depth + 1)
            return nothing
        end
    end
end

function test_existing_vector(daf::DafReader, depth::Int)::Nothing
    if depth > 3
        return nothing
    end

    if daf isa DafWriter
        nested_test("read_only") do
            test_existing_vector(read_only(daf), depth)
            return nothing
        end
    end

    nested_test("has_vector") do
        @test has_vector(daf, "gene", "marker")
    end

    nested_test("vector_names") do
        @test vector_names(daf, "gene") == Set(["marker"])
    end

    nested_test("get_vector") do
        nested_test("()") do
            @test get_vector(daf, "gene", "marker") == MARKER_GENES_BY_DEPTH[depth - 1]
            @test dimnames(get_vector(daf, "gene", "marker")) == ["gene"]
            @test names(get_vector(daf, "gene", "marker")) == [GENE_NAMES]
        end

        nested_test("default") do
            nested_test("()") do
                @test get_vector(daf, "gene", "marker"; default = [false, false, false, false]) ==
                      MARKER_GENES_BY_DEPTH[depth - 1]
                @test dimnames(get_vector(daf, "gene", "marker"; default = [false, false, false, false])) == ["gene"]
                @test names(get_vector(daf, "gene", "marker"; default = [false, false, false, false])) == [GENE_NAMES]
            end

            nested_test("!size") do
                @test_throws dedent("""
                    default length: 3
                    is different from the length: 4
                    of the axis: gene
                    in the daf data: $(daf.name)
                """) get_vector(daf, "gene", "marker"; default = [false, false, false])
            end
        end
    end

    if !(daf isa DafWriter)
        return nothing
    end

    nested_test("delete_vector!") do
        nested_test("()") do
            @test delete_vector!(daf, "gene", "marker") == nothing
            nested_test("deleted") do
                test_missing_vector(daf, depth + 1)
                return nothing
            end
        end

        nested_test("must_exist") do
            nested_test("true") do
                @test delete_vector!(daf, "gene", "marker"; must_exist = true) == nothing
                nested_test("deleted") do
                    test_missing_vector(daf, depth + 1)
                    return nothing
                end
            end

            nested_test("false") do
                @test delete_vector!(daf, "gene", "marker"; must_exist = false) == nothing
                nested_test("deleted") do
                    test_missing_vector(daf, depth + 1)
                    return nothing
                end
            end
        end
    end

    nested_test("delete_axis!") do
        @test delete_axis!(daf, "gene") == nothing
        test_missing_vector_axis(daf, depth + 1)
        return nothing
    end

    nested_test("set_vector!") do
        nested_test("()") do
            @test_throws dedent("""
                existing vector: marker
                for the axis: gene
                in the daf data: $(daf.name)
            """) set_vector!(daf, "gene", "marker", MARKER_GENES_BY_DEPTH[depth])
        end

        nested_test("overwrite") do
            nested_test("false") do
                @test_throws dedent("""
                    existing vector: marker
                    for the axis: gene
                    in the daf data: $(daf.name)
                """) set_vector!(daf, "gene", "marker", MARKER_GENES_BY_DEPTH[depth]; overwrite = false)
            end

            nested_test("true") do
                @test set_vector!(daf, "gene", "marker", MARKER_GENES_BY_DEPTH[depth]; overwrite = true) == nothing
                nested_test("overwritten") do
                    test_existing_vector(daf, depth + 1)
                    return nothing
                end
            end
        end
    end

    nested_test("empty_vector!") do
        nested_test("dense") do
            nested_test("()") do
                return @test_throws dedent("""
                    existing vector: marker
                    for the axis: gene
                    in the daf data: $(daf.name)
                """) empty_dense_vector!(daf, "gene", "marker", Bool) do empty
                    @assert false
                end
            end

            nested_test("overwrite") do
                nested_test("false") do
                    return @test_throws dedent("""
                        existing vector: marker
                        for the axis: gene
                        in the daf data: $(daf.name)
                    """) empty_dense_vector!(daf, "gene", "marker", Bool; overwrite = false) do empty
                        @assert false
                    end
                end

                nested_test("true") do
                    @test empty_dense_vector!(daf, "gene", "marker", Bool; overwrite = true) do empty
                        empty .= MARKER_GENES_BY_DEPTH[depth]
                        return 7
                    end == 7

                    nested_test("overwritten") do
                        test_existing_vector(daf, depth + 1)
                        return nothing
                    end
                end
            end
        end

        nested_test("sparse") do
            nested_test("()") do
                return @test_throws dedent("""
                    existing vector: marker
                    for the axis: gene
                    in the daf data: $(daf.name)
                """) empty_sparse_vector!(
                    daf,
                    "gene",
                    "marker",
                    Bool,
                    sum(MARKER_GENES_BY_DEPTH[depth]),
                    Int16,
                ) do empty
                    @assert false
                end
            end

            nested_test("overwrite") do
                nested_test("false") do
                    @test_throws dedent("""
                        existing vector: marker
                        for the axis: gene
                        in the daf data: $(daf.name)
                    """) empty_sparse_vector!(
                        daf,
                        "gene",
                        "marker",
                        Bool,
                        sum(MARKER_GENES_BY_DEPTH[depth]),
                        Int16;
                        overwrite = false,
                    ) do
                        @assert false
                    end
                end

                nested_test("true") do
                    @test empty_sparse_vector!(
                        daf,
                        "gene",
                        "marker",
                        Bool,
                        sum(MARKER_GENES_BY_DEPTH[depth]),
                        Int16;
                        overwrite = true,
                    ) do empty
                        empty .= SparseVector(MARKER_GENES_BY_DEPTH[depth])
                        return 7
                    end == 7
                    test_existing_vector(daf, depth + 1)
                    return nothing
                end
            end
        end
    end
end

function test_missing_matrix_axis(daf::DafReader, depth::Int)::Nothing
    if depth > 3
        return nothing
    end

    if daf isa DafWriter
        nested_test("read_only") do
            test_missing_matrix_axis(read_only(daf), depth)
            return nothing
        end
    end

    nested_test("has_matrix") do
        @test_throws dedent("""
            missing axis: cell
            in the daf data: $(daf.name)
        """) has_matrix(daf, "cell", "gene", "UMIs")

        if daf isa DafWriter
            @test add_axis!(daf, "cell", CELL_NAMES) == nothing
            @test_throws dedent("""
                missing axis: gene
                in the daf data: $(daf.name)
            """) has_matrix(daf, "cell", "gene", "UMIs")
        end
    end

    nested_test("matrix_names") do
        @test_throws dedent("""
            missing axis: cell
            in the daf data: $(daf.name)
        """) matrix_names(daf, "cell", "gene")

        if daf isa DafWriter
            @test add_axis!(daf, "cell", CELL_NAMES) == nothing
            @test_throws dedent("""
                missing axis: gene
                in the daf data: $(daf.name)
            """) matrix_names(daf, "cell", "gene")
        end
    end

    nested_test("get_matrix") do
        @test_throws dedent("""
            missing axis: cell
            in the daf data: $(daf.name)
        """) get_matrix(daf, "cell", "gene", "UMIs")

        if daf isa DafWriter
            @test add_axis!(daf, "cell", CELL_NAMES) == nothing
            @test_throws dedent("""
                missing axis: gene
                in the daf data: $(daf.name)
            """) get_matrix(daf, "cell", "gene", "UMIs")
        end
    end

    if !(daf isa DafWriter)
        return nothing
    end

    nested_test("delete_matrix") do
        nested_test("()") do
            @test_throws dedent("""
                missing axis: cell
                in the daf data: $(daf.name)
            """) delete_matrix!(daf, "cell", "gene", "UMIs")
            @test add_axis!(daf, "cell", CELL_NAMES) == nothing
            @test_throws dedent("""
                missing axis: gene
                in the daf data: $(daf.name)
            """) delete_matrix!(daf, "cell", "gene", "UMIs")
        end

        nested_test("must_exist") do
            nested_test("true") do
                @test_throws dedent("""
                    missing axis: cell
                    in the daf data: $(daf.name)
                """) delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = true)
                @test add_axis!(daf, "cell", CELL_NAMES) == nothing
                @test_throws dedent("""
                    missing axis: gene
                    in the daf data: $(daf.name)
                """) delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = true)
            end

            nested_test("false") do
                @test_throws dedent("""
                    missing axis: cell
                    in the daf data: $(daf.name)
                """) delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = false)
                @test add_axis!(daf, "cell", CELL_NAMES) == nothing
                @test_throws dedent("""
                    missing axis: gene
                    in the daf data: $(daf.name)
                """) delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = false)
            end
        end
    end

    nested_test("set_matrix!") do
        nested_test("()") do
            @test_throws dedent("""
                missing axis: cell
                in the daf data: $(daf.name)
            """) set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth])
            @test add_axis!(daf, "cell", CELL_NAMES) == nothing
            @test_throws dedent("""
                missing axis: gene
                in the daf data: $(daf.name)
            """) set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth])
        end

        nested_test("overwrite") do
            nested_test("false") do
                @test_throws dedent("""
                    missing axis: cell
                    in the daf data: $(daf.name)
                """) set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth]; overwrite = false)
                @test add_axis!(daf, "cell", CELL_NAMES) == nothing
                @test_throws dedent("""
                    missing axis: gene
                    in the daf data: $(daf.name)
                """) set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth]; overwrite = false)
            end

            nested_test("true") do
                @test_throws dedent("""
                    missing axis: cell
                    in the daf data: $(daf.name)
                """) set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth]; overwrite = true)
                @test add_axis!(daf, "cell", CELL_NAMES) == nothing
                @test_throws dedent("""
                    missing axis: gene
                    in the daf data: $(daf.name)
                """) set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth]; overwrite = true)
            end
        end
    end
end

function test_missing_matrix(daf::DafReader, depth::Int)::Nothing
    if depth > 3
        return nothing
    end

    if daf isa DafWriter
        nested_test("read_only") do
            test_missing_matrix(read_only(daf), depth)
            return nothing
        end
    end

    nested_test("has_matrix") do
        @test !has_matrix(daf, "cell", "gene", "UMIs"; relayout = false)
    end

    nested_test("matrix_names") do
        @test isempty(matrix_names(daf, "cell", "gene"; relayout = false))
    end

    nested_test("get_matrix") do
        nested_test("relayout") do
            nested_test("default") do
                @test_throws dedent("""
                    missing matrix: UMIs
                    for the rows axis: cell
                    and the columns axis: gene
                    (and the other way around)
                    in the daf data: $(daf.name)
                """) get_matrix(daf, "cell", "gene", "UMIs")
            end

            nested_test("true") do
                @test_throws dedent("""
                    missing matrix: UMIs
                    for the rows axis: cell
                    and the columns axis: gene
                    (and the other way around)
                    in the daf data: $(daf.name)
                """) get_matrix(daf, "cell", "gene", "UMIs"; relayout = true)
            end

            nested_test("false") do
                @test_throws dedent("""
                    missing matrix: UMIs
                    for the rows axis: cell
                    and the columns axis: gene
                    in the daf data: $(daf.name)
                """) get_matrix(daf, "cell", "gene", "UMIs"; relayout = false)
            end
        end

        nested_test("default") do
            nested_test("missing") do
                @test get_matrix(daf, "cell", "gene", "UMIs"; default = nothing) == nothing
            end

            nested_test("scalar") do
                @test get_matrix(daf, "cell", "gene", "UMIs"; default = 1.0) ==
                      [1.0 1.0 1.0 1.0; 1.0 1.0 1.0 1.0; 1.0 1.0 1.0 1.0]
                @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; default = 1.0)) == ["cell", "gene"]
                @test names(get_matrix(daf, "cell", "gene", "UMIs"; default = 1.0)) == [CELL_NAMES, GENE_NAMES]
            end

            nested_test("matrix") do
                nested_test("()") do
                    @test get_matrix(
                        daf,
                        "cell",
                        "gene",
                        "UMIs";
                        default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                        relayout = false,
                    ) == [0 1 2 3; 1 2 3 4; 2 3 4 5]
                    @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1 2 3; 1 2 3 4; 2 3 4 5])) ==
                          ["cell", "gene"]
                    @test names(get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1 2 3; 1 2 3 4; 2 3 4 5])) ==
                          [CELL_NAMES, GENE_NAMES]
                end

                nested_test("transpose") do
                    @test_throws "type: Transpose{Int64, Matrix{Int64}} is not in column-major layout" get_matrix(
                        daf,
                        "cell",
                        "gene",
                        "UMIs";
                        default = transpose([0 1 2; 1 2 3; 2 3 4; 4 5 6]),
                    )
                end

                nested_test("!rows") do
                    @test_throws dedent("""
                        default rows: 2
                        is different from the length: 3
                        of the axis: cell
                        in the daf data: $(daf.name)
                    """) get_matrix(daf, "cell", "gene", "UMIs"; default = [1 2 3 4; 2 3 4 5])
                end

                nested_test("!columns") do
                    @test_throws dedent("""
                        default columns: 2
                        is different from the length: 4
                        of the axis: gene
                        in the daf data: $(daf.name)
                    """) get_matrix(daf, "cell", "gene", "UMIs"; default = [1 2; 2 3; 3 4])
                end
            end

            nested_test("named") do
                nested_test("()") do
                    @test get_matrix(
                        daf,
                        "cell",
                        "gene",
                        "UMIs";
                        default = NamedArray(
                            [0 1 2 3; 1 2 3 4; 2 3 4 5];
                            names = (CELL_NAMES, GENE_NAMES),
                            dimnames = ("cell", "gene"),
                        ),
                    ) == [0 1 2 3; 1 2 3 4; 2 3 4 5]
                    @test dimnames(
                        get_matrix(
                            daf,
                            "cell",
                            "gene",
                            "UMIs";
                            default = NamedArray(
                                [0 1 2 3; 1 2 3 4; 2 3 4 5];
                                names = (CELL_NAMES, GENE_NAMES),
                                dimnames = ("cell", "gene"),
                            ),
                        ),
                    ) == ["cell", "gene"]
                    @test names(
                        get_matrix(
                            daf,
                            "cell",
                            "gene",
                            "UMIs";
                            default = NamedArray(
                                [0 1 2 3; 1 2 3 4; 2 3 4 5];
                                names = (CELL_NAMES, GENE_NAMES),
                                dimnames = ("cell", "gene"),
                            ),
                        ),
                    ) == [CELL_NAMES, GENE_NAMES]
                end

                nested_test("!rows") do
                    nested_test("name") do
                        @test_throws dedent("""
                            row names of the: default
                            mismatch the entry names of the axis: cell
                            in the daf data: $(daf.name)
                        """) get_matrix(
                            daf,
                            "cell",
                            "gene",
                            "UMIs";
                            default = NamedArray(
                                [0 1 2 3; 1 2 3 4; 2 3 4 5];
                                names = (["A", "B", "C"], GENE_NAMES),
                                dimnames = ("cell", "gene"),
                            ),
                        )
                    end

                    nested_test("dim") do
                        @test_throws dedent("""
                            default rows dim name: A
                            is different from the rows axis: cell
                            in the daf data: $(daf.name)
                        """) get_matrix(
                            daf,
                            "cell",
                            "gene",
                            "UMIs";
                            default = NamedArray(
                                [0 1 2 3; 1 2 3 4; 2 3 4 5];
                                names = (CELL_NAMES, GENE_NAMES),
                                dimnames = ("A", "gene"),
                            ),
                        )
                    end
                end

                nested_test("!columns") do
                    nested_test("name") do
                        @test_throws dedent("""
                            column names of the: default
                            mismatch the entry names of the axis: gene
                            in the daf data: $(daf.name)
                        """) get_matrix(
                            daf,
                            "cell",
                            "gene",
                            "UMIs";
                            default = NamedArray(
                                [0 1 2 3; 1 2 3 4; 2 3 4 5];
                                names = (CELL_NAMES, ["A", "B", "C", "D"]),
                                dimnames = ("cell", "gene"),
                            ),
                        )
                    end

                    nested_test("dim") do
                        @test_throws dedent("""
                            default columns dim name: B
                            is different from the columns axis: gene
                            in the daf data: $(daf.name)
                        """) get_matrix(
                            daf,
                            "cell",
                            "gene",
                            "UMIs";
                            default = NamedArray(
                                [0 1 2 3; 1 2 3 4; 2 3 4 5];
                                names = (CELL_NAMES, GENE_NAMES),
                                dimnames = ("cell", "B"),
                            ),
                        )
                    end
                end
            end
        end
    end

    if !(daf isa DafWriter)
        return nothing
    end

    nested_test("delete_matrix") do
        nested_test("relayout") do
            nested_test("default") do
                @test_throws dedent("""
                    missing matrix: UMIs
                    for the rows axis: cell
                    and the columns axis: gene
                    (and the other way around)
                    in the daf data: $(daf.name)
                """) delete_matrix!(daf, "cell", "gene", "UMIs")
            end

            nested_test("true") do
                @test_throws dedent("""
                    missing matrix: UMIs
                    for the rows axis: cell
                    and the columns axis: gene
                    (and the other way around)
                    in the daf data: $(daf.name)
                """) delete_matrix!(daf, "cell", "gene", "UMIs"; relayout = true)
            end

            nested_test("false") do
                @test_throws dedent("""
                    missing matrix: UMIs
                    for the rows axis: cell
                    and the columns axis: gene
                    in the daf data: $(daf.name)
                """) delete_matrix!(daf, "cell", "gene", "UMIs"; relayout = false)
            end
        end

        nested_test("must_exist") do
            nested_test("true") do
                nested_test("relayout") do
                    nested_test("default") do
                        @test_throws dedent("""
                            missing matrix: UMIs
                            for the rows axis: cell
                            and the columns axis: gene
                            (and the other way around)
                            in the daf data: $(daf.name)
                        """) delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = true)
                    end

                    nested_test("true") do
                        @test_throws dedent("""
                            missing matrix: UMIs
                            for the rows axis: cell
                            and the columns axis: gene
                            (and the other way around)
                            in the daf data: $(daf.name)
                        """) delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = true, relayout = true)
                    end

                    nested_test("false") do
                        @test_throws dedent("""
                            missing matrix: UMIs
                            for the rows axis: cell
                            and the columns axis: gene
                            in the daf data: $(daf.name)
                        """) delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = true, relayout = false)
                    end
                end
            end

            nested_test("false") do
                @test delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = false) == nothing
            end
        end
    end

    nested_test("set_matrix!") do
        nested_test("scalar") do
            @test set_matrix!(daf, "cell", "gene", "UMIs", 1.0; relayout = false) == nothing
            @test get_matrix(daf, "cell", "gene", "UMIs"; relayout = false) ==
                  [1.0 1.0 1.0 1.0; 1.0 1.0 1.0 1.0; 1.0 1.0 1.0 1.0]
        end

        nested_test("matrix") do
            nested_test("relayout") do
                nested_test("default") do
                    @test set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth]) == nothing
                    test_existing_relayout_matrix(daf, depth + 1)
                    return nothing
                end

                nested_test("true") do
                    @test set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth]; relayout = true) == nothing
                    test_existing_relayout_matrix(daf, depth + 1)
                    return nothing
                end

                nested_test("false") do
                    @test set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth]; relayout = false) == nothing

                    nested_test("exists") do
                        test_existing_matrix(daf, depth + 1)
                        return nothing
                    end

                    nested_test("relayout") do
                        @test relayout_matrix!(daf, "cell", "gene", "UMIs") == nothing
                        test_existing_relayout_matrix(daf, depth + 1)
                        return nothing
                    end
                end
            end

            nested_test("transpose") do
                @test_throws "type: Transpose{Int64, Matrix{Int64}} is not in column-major layout" set_matrix!(
                    daf,
                    "cell",
                    "gene",
                    "UMIs",
                    transpose([0 1 2; 1 2 3; 2 3 4; 4 5 6]),
                )
            end

            nested_test("!rows") do
                @test_throws dedent("""
                    matrix rows: 2
                    is different from the length: 3
                    of the axis: cell
                    in the daf data: $(daf.name)
                """) set_matrix!(daf, "cell", "gene", "UMIs", [1 2 3 4; 2 3 4 5])
            end

            nested_test("!columns") do
                @test_throws dedent("""
                    matrix columns: 2
                    is different from the length: 4
                    of the axis: gene
                    in the daf data: $(daf.name)
                """) set_matrix!(daf, "cell", "gene", "UMIs", [1 2; 2 3; 3 4])
            end
        end

        nested_test("named") do
            nested_test("relayout") do
                nested_test("default") do
                    @test set_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        NamedArray(UMIS_BY_DEPTH[depth]; names = (CELL_NAMES, GENE_NAMES), dimnames = ("cell", "gene")),
                    ) == nothing
                    test_existing_relayout_matrix(daf, depth + 1)
                    return nothing
                end

                nested_test("true") do
                    @test set_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        NamedArray(UMIS_BY_DEPTH[depth]; names = (CELL_NAMES, GENE_NAMES), dimnames = ("cell", "gene"));
                        relayout = true,
                    ) == nothing
                    test_existing_relayout_matrix(daf, depth + 1)
                    return nothing
                end

                nested_test("false") do
                    @test set_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        NamedArray(UMIS_BY_DEPTH[depth]; names = (CELL_NAMES, GENE_NAMES), dimnames = ("cell", "gene"));
                        relayout = false,
                    ) == nothing

                    nested_test("exists") do
                        test_existing_matrix(daf, depth + 1)
                        return nothing
                    end

                    nested_test("relayout") do
                        @test relayout_matrix!(daf, "cell", "gene", "UMIs") == nothing
                        test_existing_relayout_matrix(daf, depth + 1)
                        return nothing
                    end
                end
            end

            nested_test("!rows") do
                nested_test("name") do
                    @test_throws dedent("""
                        row names of the: matrix
                        mismatch the entry names of the axis: cell
                        in the daf data: $(daf.name)
                    """) set_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        NamedArray(
                            UMIS_BY_DEPTH[depth];
                            names = (["A", "B", "C"], GENE_NAMES),
                            dimnames = ("cell", "gene"),
                        ),
                    )
                end

                nested_test("dim") do
                    @test_throws dedent("""
                        matrix rows dim name: A
                        is different from the rows axis: cell
                        in the daf data: $(daf.name)
                    """) set_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        NamedArray(UMIS_BY_DEPTH[depth]; names = (CELL_NAMES, GENE_NAMES), dimnames = ("A", "gene")),
                    )
                end
            end

            nested_test("!columns") do
                nested_test("name") do
                    @test_throws dedent("""
                        column names of the: matrix
                        mismatch the entry names of the axis: gene
                        in the daf data: $(daf.name)
                    """) set_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        NamedArray(
                            UMIS_BY_DEPTH[depth];
                            names = (CELL_NAMES, ["A", "B", "C", "D"]),
                            dimnames = ("cell", "gene"),
                        ),
                    )
                end

                nested_test("dim") do
                    @test_throws dedent("""
                        matrix columns dim name: B
                        is different from the columns axis: gene
                        in the daf data: $(daf.name)
                    """) set_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        NamedArray(UMIS_BY_DEPTH[depth]; names = (CELL_NAMES, GENE_NAMES), dimnames = ("cell", "B")),
                    )
                end
            end
        end
    end

    nested_test("empty_matrix!") do
        nested_test("dense") do
            @test empty_dense_matrix!(daf, "cell", "gene", "UMIs", Int16) do empty
                empty .= UMIS_BY_DEPTH[depth]
                return 7
            end == 7

            nested_test("exists") do
                test_existing_matrix(daf, depth + 1)
                return nothing
            end

            nested_test("relayout") do
                @test relayout_matrix!(daf, "cell", "gene", "UMIs") == nothing
                test_existing_relayout_matrix(daf, depth + 1)
                return nothing
            end
        end

        nested_test("sparse") do
            @test empty_sparse_matrix!(
                daf,
                "cell",
                "gene",
                "UMIs",
                Int16,
                sum(UMIS_BY_DEPTH[depth] .> 0),
                Int16,
            ) do empty
                sparse = SparseMatrixCSC(UMIS_BY_DEPTH[depth])
                empty.array.colptr .= sparse.colptr
                empty.array.rowval .= sparse.rowval
                empty.array.nzval .= sparse.nzval
                return 7
            end == 7

            nested_test("exists") do
                test_existing_matrix(daf, depth + 1)
                return nothing
            end

            nested_test("relayout") do
                @test relayout_matrix!(daf, "cell", "gene", "UMIs") == nothing
                test_existing_relayout_matrix(daf, depth + 1)
                return nothing
            end
        end
    end
end

function test_existing_matrix(daf::DafReader, depth::Int)::Nothing
    if depth > 3
        return nothing
    end

    if daf isa DafWriter
        nested_test("read_only") do
            test_existing_matrix(read_only(daf), depth)
            return nothing
        end
    end

    nested_test("has_matrix") do
        nested_test("relayout") do
            nested_test("default") do
                @test has_matrix(daf, "cell", "gene", "UMIs")
                @test has_matrix(daf, "gene", "cell", "UMIs")
            end

            nested_test("true") do
                @test has_matrix(daf, "cell", "gene", "UMIs"; relayout = true)
                @test has_matrix(daf, "gene", "cell", "UMIs"; relayout = true)
            end

            nested_test("false") do
                @test has_matrix(daf, "cell", "gene", "UMIs"; relayout = false)
                @test !has_matrix(daf, "gene", "cell", "UMIs"; relayout = false)
            end
        end
    end

    nested_test("matrix_names") do
        nested_test("relayout") do
            nested_test("default") do
                @test matrix_names(daf, "cell", "gene") == Set(["UMIs"])
                @test matrix_names(daf, "gene", "cell") == Set(["UMIs"])
            end

            nested_test("true") do
                @test matrix_names(daf, "cell", "gene"; relayout = true) == Set(["UMIs"])
                @test matrix_names(daf, "gene", "cell"; relayout = true) == Set(["UMIs"])
            end

            nested_test("false") do
                @test matrix_names(daf, "cell", "gene"; relayout = false) == Set(["UMIs"])
                @test isempty(matrix_names(daf, "gene", "cell"; relayout = false))
            end
        end
    end

    nested_test("get_matrix") do
        nested_test("relayout") do
            nested_test("default") do
                @test get_matrix(daf, "cell", "gene", "UMIs") == UMIS_BY_DEPTH[depth - 1]
                @test dimnames(get_matrix(daf, "cell", "gene", "UMIs")) == ["cell", "gene"]
                @test names(get_matrix(daf, "cell", "gene", "UMIs")) == [CELL_NAMES, GENE_NAMES]

                @test get_matrix(daf, "gene", "cell", "UMIs") == transpose(UMIS_BY_DEPTH[depth - 1])
                @test dimnames(get_matrix(daf, "gene", "cell", "UMIs")) == ["gene", "cell"]
                @test names(get_matrix(daf, "gene", "cell", "UMIs")) == [GENE_NAMES, CELL_NAMES]

                if !(daf isa DafWriter)
                    daf = daf.daf
                end

                nested_test("!axes") do
                    @test delete_axis!(daf, "cell") == nothing
                    @test delete_axis!(daf, "gene") == nothing
                    test_missing_matrix_axis(daf, depth + 1)
                    return nothing
                end
            end

            nested_test("true") do
                @test get_matrix(daf, "cell", "gene", "UMIs"; relayout = true) == UMIS_BY_DEPTH[depth - 1]
                @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; relayout = true)) == ["cell", "gene"]
                @test names(get_matrix(daf, "cell", "gene", "UMIs"; relayout = true)) == [CELL_NAMES, GENE_NAMES]

                @test get_matrix(daf, "gene", "cell", "UMIs"; relayout = true) == transpose(UMIS_BY_DEPTH[depth - 1])
                @test dimnames(get_matrix(daf, "gene", "cell", "UMIs"; relayout = true)) == ["gene", "cell"]
                @test names(get_matrix(daf, "gene", "cell", "UMIs"; relayout = true)) == [GENE_NAMES, CELL_NAMES]

                if !(daf isa DafWriter)
                    daf = daf.daf
                end

                nested_test("!axes") do
                    @test delete_axis!(daf, "cell") == nothing
                    @test delete_axis!(daf, "gene") == nothing
                    test_missing_matrix_axis(daf, depth + 1)
                    return nothing
                end
            end

            nested_test("false") do
                @test get_matrix(daf, "cell", "gene", "UMIs"; relayout = false) == UMIS_BY_DEPTH[depth - 1]
                @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; relayout = false)) == ["cell", "gene"]
                @test names(get_matrix(daf, "cell", "gene", "UMIs"; relayout = false)) == [CELL_NAMES, GENE_NAMES]

                @test_throws dedent("""
                    missing matrix: UMIs
                    for the rows axis: gene
                    and the columns axis: cell
                    in the daf data: $(daf.name)
                """) get_matrix(daf, "gene", "cell", "UMIs"; relayout = false)
            end
        end

        nested_test("default") do
            nested_test("scalar") do
                nested_test("relayout") do
                    nested_test("default") do
                        @test get_matrix(daf, "cell", "gene", "UMIs"; default = 1) == UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; default = 1)) == ["cell", "gene"]
                        @test names(get_matrix(daf, "cell", "gene", "UMIs"; default = 1)) == [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(daf, "gene", "cell", "UMIs"; default = 1) ==
                              transpose(UMIS_BY_DEPTH[depth - 1])
                        @test dimnames(get_matrix(daf, "gene", "cell", "UMIs"; default = 1)) == ["gene", "cell"]
                        @test names(get_matrix(daf, "gene", "cell", "UMIs"; default = 1)) == [GENE_NAMES, CELL_NAMES]
                    end

                    nested_test("true") do
                        @test get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = true) ==
                              UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = true)) ==
                              ["cell", "gene"]
                        @test names(get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = true)) ==
                              [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = true) ==
                              transpose(UMIS_BY_DEPTH[depth - 1])
                        @test dimnames(get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = true)) ==
                              ["gene", "cell"]
                        @test names(get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = true)) ==
                              [GENE_NAMES, CELL_NAMES]
                    end

                    nested_test("false") do
                        @test get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = false) ==
                              UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = false)) ==
                              ["cell", "gene"]
                        @test names(get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = false)) ==
                              [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = false) ==
                              [1 1 1; 1 1 1; 1 1 1; 1 1 1]
                        @test dimnames(get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = true)) ==
                              ["gene", "cell"]
                        @test names(get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = true)) ==
                              [GENE_NAMES, CELL_NAMES]
                    end
                end
            end

            nested_test("matrix") do
                nested_test("relayout") do
                    nested_test("default") do
                        @test get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1 2 3; 1 2 3 4; 2 3 4 5]) ==
                              UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(
                            get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1 2 3; 1 2 3 4; 2 3 4 5]),
                        ) == ["cell", "gene"]
                        @test names(get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1 2 3; 1 2 3 4; 2 3 4 5])) ==
                              [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(daf, "gene", "cell", "UMIs"; default = [0 1 2; 1 2 3; 2 3 4; 4 5 6]) ==
                              transpose(UMIS_BY_DEPTH[depth - 1])
                        @test dimnames(
                            get_matrix(daf, "gene", "cell", "UMIs"; default = [0 1 2; 1 2 3; 2 3 4; 4 5 6]),
                        ) == ["gene", "cell"]
                        @test names(get_matrix(daf, "gene", "cell", "UMIs"; default = [0 1 2; 1 2 3; 2 3 4; 4 5 6])) ==
                              [GENE_NAMES, CELL_NAMES]
                    end

                    nested_test("true") do
                        @test get_matrix(
                            daf,
                            "cell",
                            "gene",
                            "UMIs";
                            default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                            relayout = true,
                        ) == UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(
                            get_matrix(
                                daf,
                                "cell",
                                "gene",
                                "UMIs";
                                default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                                relayout = true,
                            ),
                        ) == ["cell", "gene"]
                        @test names(
                            get_matrix(
                                daf,
                                "cell",
                                "gene",
                                "UMIs";
                                default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                                relayout = true,
                            ),
                        ) == [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(
                            daf,
                            "gene",
                            "cell",
                            "UMIs";
                            default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                            relayout = true,
                        ) == transpose(UMIS_BY_DEPTH[depth - 1])
                        @test dimnames(
                            get_matrix(
                                daf,
                                "gene",
                                "cell",
                                "UMIs";
                                default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                                relayout = true,
                            ),
                        ) == ["gene", "cell"]
                        @test names(
                            get_matrix(
                                daf,
                                "gene",
                                "cell",
                                "UMIs";
                                default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                                relayout = true,
                            ),
                        ) == [GENE_NAMES, CELL_NAMES]
                    end

                    nested_test("false") do
                        @test get_matrix(
                            daf,
                            "cell",
                            "gene",
                            "UMIs";
                            default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                            relayout = false,
                        ) == UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(
                            get_matrix(
                                daf,
                                "cell",
                                "gene",
                                "UMIs";
                                default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                                relayout = false,
                            ),
                        ) == ["cell", "gene"]
                        @test names(
                            get_matrix(
                                daf,
                                "cell",
                                "gene",
                                "UMIs";
                                default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                                relayout = false,
                            ),
                        ) == [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(
                            daf,
                            "gene",
                            "cell",
                            "UMIs";
                            default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                            relayout = false,
                        ) == [0 1 2; 1 2 3; 2 3 4; 4 5 6]
                        @test dimnames(
                            get_matrix(
                                daf,
                                "gene",
                                "cell",
                                "UMIs";
                                default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                                relayout = false,
                            ),
                        ) == ["gene", "cell"]
                        @test names(
                            get_matrix(
                                daf,
                                "gene",
                                "cell",
                                "UMIs";
                                default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                                relayout = false,
                            ),
                        ) == [GENE_NAMES, CELL_NAMES]
                    end
                end

                nested_test("!rows") do
                    @test_throws dedent("""
                        default rows: 2
                        is different from the length: 3
                        of the axis: cell
                        in the daf data: $(daf.name)
                    """) get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1 2 3; 4 5 6 7])
                end

                nested_test("!columns") do
                    @test_throws dedent("""
                        default columns: 2
                        is different from the length: 4
                        of the axis: gene
                        in the daf data: $(daf.name)
                    """) get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1; 2 3; 4 5])
                end
            end
        end
    end

    if !(daf isa DafWriter)
        return nothing
    end

    nested_test("delete_matrix!") do
        nested_test("()") do
            @test delete_matrix!(daf, "cell", "gene", "UMIs"; relayout = false) == nothing
            nested_test("deleted") do
                test_missing_matrix(daf, depth + 1)
                return nothing
            end
        end

        nested_test("must_exist") do
            nested_test("true") do
                @test delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = true, relayout = false) == nothing
                nested_test("deleted") do
                    test_missing_matrix(daf, depth + 1)
                    return nothing
                end
            end

            nested_test("false") do
                @test delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = false, relayout = false) == nothing
                nested_test("deleted") do
                    test_missing_matrix(daf, depth + 1)
                    return nothing
                end
            end
        end
    end

    nested_test("delete_axis!") do
        @test delete_axis!(daf, "gene") == nothing
        @test delete_axis!(daf, "cell") == nothing
        test_missing_matrix_axis(daf, depth + 1)
        return nothing
    end

    nested_test("set_matrix!") do
        nested_test("scalar") do
            nested_test("overwrite") do
                nested_test("default") do
                    @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) set_matrix!(daf, "cell", "gene", "UMIs", 1)
                end

                nested_test("false") do
                    @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) set_matrix!(daf, "cell", "gene", "UMIs", 1; overwrite = false)
                end

                nested_test("true") do
                    @test set_matrix!(daf, "cell", "gene", "UMIs", 1; overwrite = true, relayout = false) == nothing
                    @test get_matrix(daf, "cell", "gene", "UMIs"; relayout = false) == [1 1 1 1; 1 1 1 1; 1 1 1 1]
                end
            end
        end

        nested_test("matrix") do
            nested_test("overwrite") do
                nested_test("default") do
                    @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth])
                end

                nested_test("false") do
                    @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth]; overwrite = false)
                end

                nested_test("true") do
                    nested_test("relayout") do
                        nested_test("default") do
                            @test set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth]; overwrite = true) ==
                                  nothing
                            nested_test("overwritten") do
                                test_existing_relayout_matrix(daf, depth + 1)
                                return nothing
                            end
                        end

                        nested_test("true") do
                            @test set_matrix!(
                                daf,
                                "cell",
                                "gene",
                                "UMIs",
                                UMIS_BY_DEPTH[depth];
                                overwrite = true,
                                relayout = true,
                            ) == nothing
                            nested_test("overwritten") do
                                test_existing_relayout_matrix(daf, depth + 1)
                                return nothing
                            end
                        end

                        nested_test("false") do
                            @test set_matrix!(
                                daf,
                                "cell",
                                "gene",
                                "UMIs",
                                UMIS_BY_DEPTH[depth];
                                overwrite = true,
                                relayout = false,
                            ) == nothing
                            nested_test("overwritten") do
                                test_existing_matrix(daf, depth + 1)
                                return nothing
                            end
                        end
                    end
                end
            end
        end
    end

    nested_test("empty_matrix!") do
        nested_test("dense") do
            nested_test("overwrite") do
                nested_test("default") do
                    return @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) empty_dense_matrix!(daf, "cell", "gene", "UMIs", Int16) do empty
                        @assert false
                    end
                end

                nested_test("false") do
                    return @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) empty_dense_matrix!(daf, "cell", "gene", "UMIs", Int16; overwrite = false) do empty
                        @assert false
                    end
                end

                nested_test("true") do
                    @test empty_dense_matrix!(daf, "cell", "gene", "UMIs", Int16; overwrite = true) do empty
                        empty .= UMIS_BY_DEPTH[depth]
                        return 7
                    end == 7

                    nested_test("overwritten") do
                        test_existing_matrix(daf, depth + 1)
                        return nothing
                    end

                    nested_test("relayout") do
                        @test relayout_matrix!(daf, "cell", "gene", "UMIs") == nothing
                        test_existing_relayout_matrix(daf, depth + 1)
                        return nothing
                    end
                end
            end
        end

        nested_test("sparse") do
            nested_test("overwrite") do
                nested_test("default") do
                    return @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) empty_sparse_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        Int16,
                        sum(UMIS_BY_DEPTH[depth] .> 0),
                        Int16,
                    ) do empty
                        @assert false
                    end
                end

                nested_test("false") do
                    return @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) empty_sparse_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        Int16,
                        sum(UMIS_BY_DEPTH[depth] .> 0),
                        Int16;
                        overwrite = false,
                    ) do empty
                        @assert false
                    end
                end

                nested_test("true") do
                    @test empty_sparse_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        Int16,
                        sum(UMIS_BY_DEPTH[depth] .> 0),
                        Int16;
                        overwrite = true,
                    ) do empty
                        sparse = SparseMatrixCSC(UMIS_BY_DEPTH[depth])
                        empty.array.colptr .= sparse.colptr
                        empty.array.rowval .= sparse.rowval
                        empty.array.nzval .= sparse.nzval
                        return 7
                    end == 7

                    nested_test("overwritten") do
                        test_existing_matrix(daf, depth + 1)
                        return nothing
                    end

                    nested_test("relayout") do
                        @test relayout_matrix!(daf, "cell", "gene", "UMIs") == nothing
                        test_existing_relayout_matrix(daf, depth + 1)
                        return nothing
                    end
                end
            end
        end
    end
end

function test_existing_relayout_matrix(daf::DafReader, depth::Int)::Nothing
    if depth > 3
        return nothing
    end

    if daf isa DafWriter
        nested_test("read_only") do
            test_existing_relayout_matrix(read_only(daf), depth)
            return nothing
        end
    end

    nested_test("has_matrix") do
        nested_test("relayout") do
            nested_test("default") do
                @test has_matrix(daf, "cell", "gene", "UMIs")
                @test has_matrix(daf, "gene", "cell", "UMIs")
            end

            nested_test("true") do
                @test has_matrix(daf, "cell", "gene", "UMIs"; relayout = true)
                @test has_matrix(daf, "gene", "cell", "UMIs"; relayout = true)
            end

            nested_test("false") do
                @test has_matrix(daf, "cell", "gene", "UMIs"; relayout = false)
                @test has_matrix(daf, "gene", "cell", "UMIs"; relayout = false)
            end
        end
    end

    nested_test("matrix_names") do
        nested_test("relayout") do
            nested_test("default") do
                @test matrix_names(daf, "cell", "gene") == Set(["UMIs"])
                @test matrix_names(daf, "gene", "cell") == Set(["UMIs"])
            end

            nested_test("true") do
                @test matrix_names(daf, "cell", "gene"; relayout = true) == Set(["UMIs"])
                @test matrix_names(daf, "gene", "cell"; relayout = true) == Set(["UMIs"])
            end

            nested_test("false") do
                @test matrix_names(daf, "cell", "gene"; relayout = false) == Set(["UMIs"])
                @test matrix_names(daf, "gene", "cell"; relayout = false) == Set(["UMIs"])
            end
        end
    end

    nested_test("get_matrix") do
        nested_test("relayout") do
            nested_test("default") do
                @test get_matrix(daf, "cell", "gene", "UMIs") == UMIS_BY_DEPTH[depth - 1]
                @test dimnames(get_matrix(daf, "cell", "gene", "UMIs")) == ["cell", "gene"]
                @test names(get_matrix(daf, "cell", "gene", "UMIs")) == [CELL_NAMES, GENE_NAMES]

                @test get_matrix(daf, "gene", "cell", "UMIs") == transpose(UMIS_BY_DEPTH[depth - 1])
                @test dimnames(get_matrix(daf, "gene", "cell", "UMIs")) == ["gene", "cell"]
                @test names(get_matrix(daf, "gene", "cell", "UMIs")) == [GENE_NAMES, CELL_NAMES]

                if !(daf isa DafWriter)
                    daf = daf.daf
                end

                nested_test("!axes") do
                    @test delete_axis!(daf, "cell") == nothing
                    @test delete_axis!(daf, "gene") == nothing
                    test_missing_matrix_axis(daf, depth + 1)
                    return nothing
                end
            end

            nested_test("true") do
                @test get_matrix(daf, "cell", "gene", "UMIs"; relayout = true) == UMIS_BY_DEPTH[depth - 1]
                @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; relayout = true)) == ["cell", "gene"]
                @test names(get_matrix(daf, "cell", "gene", "UMIs"; relayout = true)) == [CELL_NAMES, GENE_NAMES]

                @test get_matrix(daf, "gene", "cell", "UMIs"; relayout = true) == transpose(UMIS_BY_DEPTH[depth - 1])
                @test dimnames(get_matrix(daf, "gene", "cell", "UMIs"; relayout = true)) == ["gene", "cell"]
                @test names(get_matrix(daf, "gene", "cell", "UMIs"; relayout = true)) == [GENE_NAMES, CELL_NAMES]
            end

            nested_test("false") do
                @test get_matrix(daf, "cell", "gene", "UMIs"; relayout = false) == UMIS_BY_DEPTH[depth - 1]
                @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; relayout = false)) == ["cell", "gene"]
                @test names(get_matrix(daf, "cell", "gene", "UMIs"; relayout = false)) == [CELL_NAMES, GENE_NAMES]

                @test get_matrix(daf, "gene", "cell", "UMIs"; relayout = false) == transpose(UMIS_BY_DEPTH[depth - 1])
                @test dimnames(get_matrix(daf, "gene", "cell", "UMIs"; relayout = false)) == ["gene", "cell"]
                @test names(get_matrix(daf, "gene", "cell", "UMIs"; relayout = false)) == [GENE_NAMES, CELL_NAMES]
            end
        end

        nested_test("default") do
            nested_test("scalar") do
                nested_test("relayout") do
                    nested_test("default") do
                        @test get_matrix(daf, "cell", "gene", "UMIs"; default = 1) == UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; default = 1)) == ["cell", "gene"]
                        @test names(get_matrix(daf, "cell", "gene", "UMIs"; default = 1)) == [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(daf, "gene", "cell", "UMIs"; default = 1) ==
                              transpose(UMIS_BY_DEPTH[depth - 1])
                        @test dimnames(get_matrix(daf, "gene", "cell", "UMIs"; default = 1)) == ["gene", "cell"]
                        @test names(get_matrix(daf, "gene", "cell", "UMIs"; default = 1)) == [GENE_NAMES, CELL_NAMES]
                    end

                    nested_test("true") do
                        @test get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = true) ==
                              UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = true)) ==
                              ["cell", "gene"]
                        @test names(get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = true)) ==
                              [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = true) ==
                              transpose(UMIS_BY_DEPTH[depth - 1])
                        @test dimnames(get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = true)) ==
                              ["gene", "cell"]
                        @test names(get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = true)) ==
                              [GENE_NAMES, CELL_NAMES]
                    end

                    nested_test("false") do
                        @test get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = false) ==
                              UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = false)) ==
                              ["cell", "gene"]
                        @test names(get_matrix(daf, "cell", "gene", "UMIs"; default = 1, relayout = false)) ==
                              [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = false) ==
                              transpose(UMIS_BY_DEPTH[depth - 1])
                        @test dimnames(get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = false)) ==
                              ["gene", "cell"]
                        @test names(get_matrix(daf, "gene", "cell", "UMIs"; default = 1, relayout = false)) ==
                              [GENE_NAMES, CELL_NAMES]
                    end
                end
            end

            nested_test("matrix") do
                nested_test("relayout") do
                    nested_test("default") do
                        @test get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1 2 3; 1 2 3 4; 2 3 4 5]) ==
                              UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(
                            get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1 2 3; 1 2 3 4; 2 3 4 5]),
                        ) == ["cell", "gene"]
                        @test names(get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1 2 3; 1 2 3 4; 2 3 4 5])) ==
                              [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(daf, "gene", "cell", "UMIs"; default = [0 1 2; 1 2 3; 2 3 4; 4 5 6]) ==
                              transpose(UMIS_BY_DEPTH[depth - 1])
                        @test dimnames(
                            get_matrix(daf, "gene", "cell", "UMIs"; default = [0 1 2; 1 2 3; 2 3 4; 4 5 6]),
                        ) == ["gene", "cell"]
                        @test names(get_matrix(daf, "gene", "cell", "UMIs"; default = [0 1 2; 1 2 3; 2 3 4; 4 5 6])) ==
                              [GENE_NAMES, CELL_NAMES]
                    end

                    nested_test("true") do
                        @test get_matrix(
                            daf,
                            "cell",
                            "gene",
                            "UMIs";
                            default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                            relayout = true,
                        ) == UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(
                            get_matrix(
                                daf,
                                "cell",
                                "gene",
                                "UMIs";
                                default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                                relayout = true,
                            ),
                        ) == ["cell", "gene"]
                        @test names(
                            get_matrix(
                                daf,
                                "cell",
                                "gene",
                                "UMIs";
                                default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                                relayout = true,
                            ),
                        ) == [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(
                            daf,
                            "gene",
                            "cell",
                            "UMIs";
                            default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                            relayout = true,
                        ) == transpose(UMIS_BY_DEPTH[depth - 1])
                        @test dimnames(
                            get_matrix(
                                daf,
                                "gene",
                                "cell",
                                "UMIs";
                                default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                                relayout = true,
                            ),
                        ) == ["gene", "cell"]
                        @test names(
                            get_matrix(
                                daf,
                                "gene",
                                "cell",
                                "UMIs";
                                default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                                relayout = true,
                            ),
                        ) == [GENE_NAMES, CELL_NAMES]
                    end

                    nested_test("false") do
                        @test get_matrix(
                            daf,
                            "cell",
                            "gene",
                            "UMIs";
                            default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                            relayout = false,
                        ) == UMIS_BY_DEPTH[depth - 1]
                        @test dimnames(
                            get_matrix(
                                daf,
                                "cell",
                                "gene",
                                "UMIs";
                                default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                                relayout = false,
                            ),
                        ) == ["cell", "gene"]
                        @test names(
                            get_matrix(
                                daf,
                                "cell",
                                "gene",
                                "UMIs";
                                default = [0 1 2 3; 1 2 3 4; 2 3 4 5],
                                relayout = false,
                            ),
                        ) == [CELL_NAMES, GENE_NAMES]

                        @test get_matrix(
                            daf,
                            "gene",
                            "cell",
                            "UMIs";
                            default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                            relayout = false,
                        ) == transpose(UMIS_BY_DEPTH[depth - 1])
                        @test dimnames(
                            get_matrix(
                                daf,
                                "gene",
                                "cell",
                                "UMIs";
                                default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                                relayout = false,
                            ),
                        ) == ["gene", "cell"]
                        @test names(
                            get_matrix(
                                daf,
                                "gene",
                                "cell",
                                "UMIs";
                                default = [0 1 2; 1 2 3; 2 3 4; 4 5 6],
                                relayout = false,
                            ),
                        ) == [GENE_NAMES, CELL_NAMES]
                    end
                end

                nested_test("!rows") do
                    @test_throws dedent("""
                        default rows: 2
                        is different from the length: 3
                        of the axis: cell
                        in the daf data: $(daf.name)
                    """) get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1 2 3; 4 5 6 7])
                end

                nested_test("!columns") do
                    @test_throws dedent("""
                        default columns: 2
                        is different from the length: 4
                        of the axis: gene
                        in the daf data: $(daf.name)
                    """) get_matrix(daf, "cell", "gene", "UMIs"; default = [0 1; 2 3; 4 5])
                end
            end
        end
    end

    if !(daf isa DafWriter)
        return nothing
    end

    nested_test("delete_matrix!") do
        nested_test("relayout") do
            nested_test("default") do
                @test delete_matrix!(daf, "gene", "cell", "UMIs") == nothing
                nested_test("deleted") do
                    test_missing_matrix(daf, depth + 1)
                    return nothing
                end
            end

            nested_test("true") do
                @test delete_matrix!(daf, "gene", "cell", "UMIs"; relayout = true) == nothing
                nested_test("deleted") do
                    test_missing_matrix(daf, depth + 1)
                    return nothing
                end
            end

            nested_test("false") do
                @test delete_matrix!(daf, "gene", "cell", "UMIs"; relayout = false) == nothing
                nested_test("deleted") do
                    test_existing_matrix(daf, depth)
                    return nothing
                end
            end
        end

        nested_test("must_exist") do
            nested_test("true") do
                @test delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = true) == nothing
                nested_test("deleted") do
                    test_missing_matrix(daf, depth + 1)
                    return nothing
                end
            end

            nested_test("false") do
                @test delete_matrix!(daf, "cell", "gene", "UMIs"; must_exist = false) == nothing
                nested_test("deleted") do
                    test_missing_matrix(daf, depth + 1)
                    return nothing
                end
            end
        end
    end

    nested_test("delete_axis!") do
        @test delete_axis!(daf, "gene") == nothing
        @test delete_axis!(daf, "cell") == nothing
        test_missing_matrix_axis(daf, depth + 1)
        return nothing
    end

    nested_test("set_matrix!") do
        nested_test("scalar") do
            nested_test("overwrite") do
                nested_test("default") do
                    @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) set_matrix!(daf, "cell", "gene", "UMIs", 1)
                end

                nested_test("false") do
                    @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) set_matrix!(daf, "cell", "gene", "UMIs", 1; overwrite = false)
                end

                nested_test("true") do
                    @test set_matrix!(daf, "cell", "gene", "UMIs", 1; overwrite = true, relayout = false) == nothing
                    @test get_matrix(daf, "cell", "gene", "UMIs"; relayout = false) == [1 1 1 1; 1 1 1 1; 1 1 1 1]
                end
            end
        end

        nested_test("matrix") do
            nested_test("overwrite") do
                nested_test("default") do
                    @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth])
                end

                nested_test("false") do
                    @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth]; overwrite = false)
                end

                nested_test("true") do
                    nested_test("relayout") do
                        nested_test("default") do
                            @test set_matrix!(daf, "cell", "gene", "UMIs", UMIS_BY_DEPTH[depth]; overwrite = true) ==
                                  nothing
                            nested_test("overwritten") do
                                test_existing_relayout_matrix(daf, depth + 1)
                                return nothing
                            end
                        end

                        nested_test("true") do
                            @test set_matrix!(
                                daf,
                                "cell",
                                "gene",
                                "UMIs",
                                UMIS_BY_DEPTH[depth];
                                overwrite = true,
                                relayout = true,
                            ) == nothing
                            nested_test("overwritten") do
                                test_existing_relayout_matrix(daf, depth + 1)
                                return nothing
                            end
                        end

                        nested_test("false") do
                            @test set_matrix!(
                                daf,
                                "cell",
                                "gene",
                                "UMIs",
                                UMIS_BY_DEPTH[depth];
                                overwrite = true,
                                relayout = false,
                            ) == nothing

                            nested_test("delete") do
                                @test delete_matrix!(daf, "gene", "cell", "UMIs"; relayout = false) == nothing
                                test_existing_matrix(daf, depth + 1)
                                return nothing
                            end

                            nested_test("relayout") do
                                nested_test("overwrite") do
                                    nested_test("default") do
                                        @test_throws dedent("""
                                            existing matrix: UMIs
                                            for the rows axis: gene
                                            and the columns axis: cell
                                            in the daf data: $(daf.name)
                                        """) relayout_matrix!(daf, "cell", "gene", "UMIs") == nothing
                                    end

                                    nested_test("false") do
                                        @test_throws dedent("""
                                            existing matrix: UMIs
                                            for the rows axis: gene
                                            and the columns axis: cell
                                            in the daf data: $(daf.name)
                                        """) relayout_matrix!(daf, "cell", "gene", "UMIs"; overwrite = false) == nothing
                                    end

                                    nested_test("true") do
                                        @test relayout_matrix!(daf, "cell", "gene", "UMIs"; overwrite = true) == nothing
                                        test_existing_relayout_matrix(daf, depth + 1)
                                        return nothing
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    nested_test("empty_matrix!") do
        nested_test("dense") do
            nested_test("overwrite") do
                nested_test("default") do
                    return @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) empty_dense_matrix!(daf, "cell", "gene", "UMIs", Int16) do empty
                        @assert false
                    end
                end

                nested_test("false") do
                    return @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) empty_dense_matrix!(daf, "cell", "gene", "UMIs", Int16; overwrite = false) do empty
                        @assert false
                    end
                end

                nested_test("true") do
                    @test empty_dense_matrix!(daf, "cell", "gene", "UMIs", Int16; overwrite = true) do empty
                        empty .= UMIS_BY_DEPTH[depth]
                        return 7
                    end == 7
                    @test delete_matrix!(daf, "gene", "cell", "UMIs"; relayout = false) == nothing

                    nested_test("overwritten") do
                        test_existing_matrix(daf, depth + 1)
                        return nothing
                    end

                    nested_test("relayout") do
                        @test relayout_matrix!(daf, "cell", "gene", "UMIs") == nothing
                        test_existing_relayout_matrix(daf, depth + 1)
                        return nothing
                    end
                end
            end
        end

        nested_test("sparse") do
            nested_test("overwrite") do
                nested_test("default") do
                    return @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) empty_sparse_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        Int16,
                        sum(UMIS_BY_DEPTH[depth] .> 0),
                        Int16,
                    ) do empty
                        @assert false
                    end
                end

                nested_test("false") do
                    return @test_throws dedent("""
                        existing matrix: UMIs
                        for the rows axis: cell
                        and the columns axis: gene
                        in the daf data: $(daf.name)
                    """) empty_sparse_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        Int16,
                        sum(UMIS_BY_DEPTH[depth] .> 0),
                        Int16;
                        overwrite = false,
                    ) do empty
                        @assert false
                    end
                end

                nested_test("true") do
                    @test empty_sparse_matrix!(
                        daf,
                        "cell",
                        "gene",
                        "UMIs",
                        Int16,
                        sum(UMIS_BY_DEPTH[depth] .> 0),
                        Int16;
                        overwrite = true,
                    ) do empty
                        sparse = SparseMatrixCSC(UMIS_BY_DEPTH[depth])
                        empty.array.colptr .= sparse.colptr
                        empty.array.rowval .= sparse.rowval
                        empty.array.nzval .= sparse.nzval
                        return 7
                    end == 7
                    @test delete_matrix!(daf, "gene", "cell", "UMIs"; relayout = false) == nothing

                    nested_test("overwritten") do
                        test_existing_matrix(daf, depth + 1)
                        return nothing
                    end

                    nested_test("relayout") do
                        @test relayout_matrix!(daf, "cell", "gene", "UMIs") == nothing
                        test_existing_relayout_matrix(daf, depth + 1)
                        return nothing
                    end
                end
            end
        end
    end
end

function test_format(daf::DafWriter)
    nested_test("scalar") do
        nested_test("missing") do
            test_missing_scalar(daf, 1)
            return nothing
        end
    end

    nested_test("axis") do
        nested_test("missing") do
            test_missing_axis(daf, 1)
            return nothing
        end
    end

    nested_test("vector") do
        nested_test("!axis") do
            test_missing_vector_axis(daf, 1)
            return nothing
        end

        nested_test("axis") do
            @test add_axis!(daf, "gene", GENE_NAMES) == nothing
            test_missing_vector(daf, 1)
            return nothing
        end
    end

    nested_test("matrix") do
        nested_test("!axes") do
            test_missing_matrix_axis(daf, 1)
            return nothing
        end

        nested_test("axes") do
            @test add_axis!(daf, "cell", CELL_NAMES) == nothing
            @test add_axis!(daf, "gene", GENE_NAMES) == nothing
            test_missing_matrix(daf, 1)
            return nothing
        end
    end
end

nested_test("data") do
    nested_test("memory") do
        daf = MemoryDaf("memory!")
        @test daf.name == "memory!"
        @test present(daf) == "MemoryDaf memory!"
        @test present(read_only(daf)) == "ReadOnly MemoryDaf memory!"
        @test description(daf) == dedent("""
            name: memory!
            type: MemoryDaf
        """) * "\n"
        test_format(daf)
        return nothing
    end
end
