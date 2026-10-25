BEGIN {
    while ((getline line < ENVIRON["RH_FIX_FUNCTIONS"])>0) functions=functions line "\n"
    close(ENVIRON["RH_FIX_FUNCTIONS"])
    if (functions=="") exit 1
}
$0=="exclude_files=(" { printf "%s",functions; anchors++ }
$0=="        $ECHO -n \"resign...\"" { print "        dedup_rpaths \"$file\""; signs++ }
$0=="    $ECHO -n \"resign...\"" { print "    dedup_rpaths \"$file\""; signs++ }
{ print }
END { if (anchors!=1 || signs!=2) exit 1 }
