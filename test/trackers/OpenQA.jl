jldf = nothing

@testset "OpenQA" begin
    datadir = joinpath(@__DIR__, "../data")
    jobtext = read(joinpath(datadir, "2069419-job-details.json"), String)
    comtext = read(joinpath(datadir, "2069419-job-comments.json"), String)
    vartext = read(joinpath(datadir, "vars.json"), String)

    job = OpenQA.json_to_job(jobtext; vars=vartext, comments=comtext)
    @test job.name == "sle-12-SP4-Server-DVD-s390x-Build0393-ltp_net_stress_interface@s390x-kvm-sle12"
    @test job.result == "failed"
    @test job.vars["MACHINE"] == "aarch64"
    @test job.comments[1].author == "pvorel"
    @test startswith(job.comments[1].text, "if4-addr-change")

    jldf = JLD2.jldopen(joinpath(datadir, "osd.jld2"), true, true, true)
    
    readdir(datadir) |> cifilter() do name
        endswith(name, "job-details.json")
    end |> cmap() do name
        joinpath(datadir, name)
    end |> cifilter() do path
        isfile(path)
    end |> cforeach() do path
        id = match(r"(\d+)-job-details.json", path)[1]
        readstr = Functional.bc(read)(String)
        jobtext = readstr(path)
        comtext = joinpath(datadir, "$id-job-comments.json") |>
            cdoif(readstr, isfile) |> cdefault("")
        vartext = joinpath(datadir, "$id-job-vars.json") |>
            cdoif(readstr, isfile) |> cdefault("")
    
        job = @test_nowarn OpenQA.json_to_job(jobtext; vars=vartext, comments=comtext)
        @test_nowarn write(jldf, "job-$id", job)
    end
end

if jldf != nothing
    close(jldf)
end
