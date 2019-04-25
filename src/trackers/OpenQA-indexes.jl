function get_recent_job_ids(jobs)
    [job.id for job in jobs if let start = start_date(job)
        start ≠ nothing && start > Date(now() - Month(1))
    end]
end
const RecentJobsDef = JobResultSetDef("recent", get_recent_job_ids)

function get_any_recent_and_older_failed_job_ids(jobs)
    today = Date(now())

    fjobs = Iterators.filter(jobs) do job
        (start = start_date(job)) ≠ nothing &&
            (start > Date(today - Month(1)) ||
             start > Date(today - Year(1)) &&
             job.state == "done" &&
             occursin(r"incomplete|^(soft)?failed", job.result))
    end
    sort!([job.id for job in fjobs]; rev=true)
end
const RecentOrInterestingJobsDef =
    JobResultSetDef("recent-or-interesting",
                    get_any_recent_and_older_failed_job_ids)
