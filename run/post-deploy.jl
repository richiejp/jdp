include("../src/init.jl")

import JDP.Spammer: post_message

function success(description, joblink)
    txt = """
New JDP build deployed
```$description```
$joblink"""

    post_message(txt, :rpalethorpe)
end

function build_failed(description, joblink)
    txt = """
JDP build/deployment failed!
```$description```
$joblink"""

    post_message(txt, :rpalethorpe)
end

function refresh_failed(joblink)
    txt = """
**JDP data refresh/reports failed!**
$joblink"""

    post_message(txt, :rpalethorpe)
end
