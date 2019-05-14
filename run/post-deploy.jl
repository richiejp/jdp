include("../src/init.jl")

import JDP.Spammer: post_message

function success(description, joblink)
    txt = """
New JDP build deployed
"$(strip(description))"
$joblink"""

    post_message(txt, :rpalethorpe)
end

function build_failed(description, joblink)
    txt = """
JDP build/deployment failed! :dizzy_face:
"$(strip(description))"
$joblink"""

    post_message(txt, :rpalethorpe)
end

function refresh_failed(joblink)
    txt = """
**JDP data refresh/reports failed!** :fearful:
$joblink"""

    post_message(txt, :rpalethorpe)
end
