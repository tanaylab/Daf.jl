"""
None

Just a function with a default x of `$(DEFAULT.x)`.
"""
@computation function none(; x = 1)
    return x
end

"""
Single

The `quality` is mandatory. The default `optional` is `$(DEFAULT.optional)`. The default `named` is `$(DEFAULT.named)`.

$(CONTRACT)
"""
@computation Contract(
    scalars = [
        "version" => (Optional, String, "In major.minor.patch format."),
        "quality" => (Guaranteed, Float64, "Overall output quality score between 0.0 and 1.0."),
    ],
    axes = ["cell" => (Required, "The sampled single cells."), "gene" => (Optional, "The sampled genes.")],
    vectors = [
        ("gene", "noisy") => (Optional, Bool, "Mask of genes with high variability."),
        ("cell", "special") => (Contingent, Bool, "Computed mask of special cells, if requested."),
    ],
    matrices = [
        ("cell", "gene", "UMIs") =>
            (Required, Union{UInt8, UInt16, UInt32, UInt64}, "The number of sampled scRNA molecules."),
    ],
) function single(daf::DafWriter, quality::Float64, optional::Int = 1; named::Int = 2)::Nothing
    set_scalar!(daf, "quality", quality)
    return nothing
end

"""
Dual

# First

$(CONTRACT1)

# Second

$(CONTRACT2)
"""
@computation Contract(
    scalars = [
        "version" => (Required, String, "In major.minor.patch format."),
        "quality" => (Guaranteed, Float64, "Overall output quality score between 0.0 and 1.0."),
    ],
) Contract(
    scalars = [
        "version" => (Guaranteed, String, "In major.minor.patch format."),
        "quality" => (Required, Float64, "Overall output quality score between 0.0 and 1.0."),
    ],
) function cross(first::DafWriter, second::DafWriter)::Nothing
    set_scalar!(second, "version", get_scalar(first, "version"))
    set_scalar!(first, "quality", get_scalar(second, "quality"))
    return nothing
end

"""
Missing

$(CONTRACT)
"""
function missing_single(daf::DafWriter)::Nothing
    return nothing
end

"""
Missing

$(DEFAULT.x)
"""
@computation Contract() function missing_default(daf::DafWriter, x::Int)::Nothing  # untested
    return nothing
end

"""
Missing

$(CONTRACT1)

$(CONTRACT2)
"""
function missing_both(first::DafWriter, second::DafWriter)::Nothing  # untested
    return nothing
end

"""
Missing

$(CONTRACT1)

$(CONTRACT2)
"""
@computation Contract() function missing_second(first::DafWriter, second::DafWriter)::Nothing  # untested
    return nothing
end

nested_test("computations") do
    nested_test("none") do
        nested_test("default") do
            @test none() == 1
        end

        nested_test("parameter") do
            @test none(; x = 2) == 2
        end

        nested_test("docs") do
            @test string(Docs.doc(none)) == dedent("""
                                             None

                                             Just a function with a default x of `1`.
                                             """) * "\n"
        end
    end

    nested_test("single") do
        daf = MemoryDaf("memory!")

        nested_test("()") do
            add_axis!(daf, "cell", ["A", "B"])
            add_axis!(daf, "gene", ["X", "Y", "Z"])
            set_matrix!(daf, "cell", "gene", "UMIs", UInt8[0 1 2; 3 4 5])
            @test single(daf, 0.0) == nothing
        end

        nested_test("missing") do
            @test_throws dedent("""
                missing input axis: cell
                for the computation: Main.single
                on the daf data: memory!
            """) single(daf, 0.0)
        end

        nested_test("docs") do
            @test string(Docs.doc(single)) ==
                  dedent(
                """
                   Single

                   The `quality` is mandatory. The default `optional` is `1`. The default `named` is `2`.

                   ## Inputs

                   ### Scalars

                   **version**::String (Optional): In major.minor.patch format.

                   ### Axes

                   **cell** (Required): The sampled single cells.

                   **gene** (Optional): The sampled genes.

                   ### Vectors

                   **gene @ noisy**::Bool (Optional): Mask of genes with high variability.

                   ### Matrices

                   **cell, gene @ UMIs**::Union{UInt16, UInt32, UInt64, UInt8} (Required): The number of sampled scRNA molecules.

                   ## Outputs

                   ### Scalars

                   **quality**::Float64 (Guaranteed): Overall output quality score between 0.0 and 1.0.

                   ### Vectors

                   **cell @ special**::Bool (Contingent): Computed mask of special cells, if requested.
               """,
            ) * "\n"
        end

        nested_test("!docs") do
            @test missing_single(daf) == nothing
            @test_throws dedent("""
                no contract(s) associated with: Main.missing_single
                use: @computation Contract(...) function Main.missing_single(...)
            """) Docs.doc(missing_single)
        end
    end

    nested_test("cross") do
        first = MemoryDaf("first!")
        second = MemoryDaf("second!")

        nested_test("()") do
            set_scalar!(first, "version", "0.0")
            set_scalar!(second, "quality", 0.0)
            @test cross(first, second) == nothing
        end

        nested_test("missing") do
            nested_test("first") do
                set_scalar!(second, "quality", 0.0)
                @test_throws dedent("""
                    missing input scalar: version
                    with type: String
                    for the computation: Main.cross
                    on the daf data: first!
                """) cross(first, second)
            end

            nested_test("second") do
                set_scalar!(first, "version", "0.0")
                @test_throws dedent("""
                    missing input scalar: quality
                    with type: Float64
                    for the computation: Main.cross
                    on the daf data: second!
                """) cross(first, second)
            end
        end

        nested_test("docs") do
            @test string(Docs.doc(cross)) == dedent("""
                Dual

                # First

                ## Inputs

                ### Scalars

                **version**::String (Required): In major.minor.patch format.

                ## Outputs

                ### Scalars

                **quality**::Float64 (Guaranteed): Overall output quality score between 0.0 and 1.0.

                # Second

                ## Inputs

                ### Scalars

                **quality**::Float64 (Required): Overall output quality score between 0.0 and 1.0.

                ## Outputs

                ### Scalars

                **version**::String (Guaranteed): In major.minor.patch format.
            """) * "\n"
        end

        nested_test("!doc1") do
            @test_throws dedent("""
                no contract(s) associated with: Main.missing_both
                use: @computation Contract(...) function Main.missing_both(...)
            """) Docs.doc(missing_both)
        end

        nested_test("!doc2") do
            @test_throws dedent("""
                no second contract associated with: Main.missing_second
                use: @computation Contract(...) Contract(...) function Main.missing_second(...)
            """) Docs.doc(missing_second)
        end

        nested_test("!default") do
            @test_throws dedent("""
                no default for a parameter: x
                in the computation: Main.missing_default
            """) Docs.doc(missing_default)
        end
    end
end