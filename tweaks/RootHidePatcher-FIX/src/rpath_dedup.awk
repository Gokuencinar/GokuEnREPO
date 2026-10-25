# Per-slice LC_RPATH deduplication. Requires binary-safe awk and LC_ALL=C.
# Usage: LC_ALL=C awk -v input=FILE [-v check=1] -f rpath_dedup.awk
# Repair writes the complete result to stdout; the caller replaces its copy.
function fail(reason) {
    print "rpath_dedup: " reason > "/dev/stderr"
    failed=1
    exit 1
}
function byte(pos) { return ord[substr(data,pos,1)] }
function u32(pos,be,  i,v) {
    v=0
    for(i=0;i<4;i++) v=v*256+byte(pos+(be ? i : 3-i))
    return v
}
function u64(pos,be,  hi,lo) {
    hi=u32(pos+(be ? 0 : 4),be)
    lo=u32(pos+(be ? 4 : 0),be)
    if(hi!=0) fail("Mach-O offset exceeds supported file size")
    return lo
}
function pack32(v,be,  i,s,c) {
    s=""
    for(i=0;i<4;i++) {
        c=sprintf("%c",v%256)
        if(be) s=c s; else s=s c
        v=int(v/256)
    }
    return s
}
function slice(start,len,  magic,be,header,n,bytes,read,end,i,cmd,size,str,path,k,kept,packed,write,zero) {
    if(len<28) fail("truncated Mach-O slice")
    magic=u32(start,0)
    be=(magic==3472551422 || magic==3489328638)
    magic=u32(start,be)
    if(magic!=4277009102 && magic!=4277009103) fail("unsupported Mach-O magic")
    header=(magic==4277009103 ? 32 : 28)
    if(len<header) fail("truncated Mach-O header")
    n=u32(start+16,be); bytes=u32(start+20,be)
    if(bytes>len-header || n>int(bytes/8)) fail("load commands exceed slice")
    read=start+header; end=read+bytes
    delete seen
    packed=""; kept=0
    for(i=0;i<n;i++) {
        if(end-read<8) fail("truncated load command")
        cmd=u32(read,be);size=u32(read+4,be)
        if(size<8 || size>end-read) fail("invalid load-command size")
        if(cmd==2147483676) {
            if(size<12) fail("truncated LC_RPATH")
            str=u32(read+8,be)
            if(str<12 || str>=size) fail("invalid LC_RPATH string offset")
            path=substr(data,read+str,size-str)
            k=index(path,nul)
            if(k==0) fail("unterminated LC_RPATH")
            path=substr(path,1,k-1)
            if(path in seen) { removed++; read+=size; continue }
            seen[path]=1
        }
        packed=packed substr(data,read,size);kept++;read+=size
    }
    if(read!=end) fail("inconsistent load-command length")
    if(!check && kept!=n) {
        zero=""
        for(i=length(packed);i<bytes;i++) zero=zero nul
        data=substr(data,1,start+15) pack32(kept,be) pack32(length(packed),be) substr(data,start+24,header-24) packed zero substr(data,end)
    }
}
BEGIN {
    BINMODE=3
    nul=sprintf("%c",0)
    for(i=0;i<256;i++) ord[sprintf("%c",i)]=i
    # An impossible separator reads the binary, including NULs, as one record.
    RS="a^"
    if(input=="") input=ENVIRON["RH_RPATH_INPUT"]
    if(input=="") fail("missing input path")
    status=(getline data < input)
    close(input)
    if(status!=1) fail("cannot read input")
    len=length(data)
    if(len<8 || len>536870912) fail("unsupported file size")
    magic=u32(1,1)
    be=(magic==3405691582 || magic==3405691583)
    fat64=(magic==3405691583 || magic==3216703178)
    if(be || magic==3199925962 || magic==3216703178) {
        count=u32(5,be); step=(fat64 ? 32 : 20)
        if(count<1 || count>64 || count>int((len-8)/step)) fail("invalid fat header")
        for(i=0;i<count;i++) {
            p=9+i*step
            starts[i]=(fat64 ? u64(p+8,be) : u32(p+8,be))
            sizes[i]=(fat64 ? u64(p+16,be) : u32(p+12,be))
            if(starts[i]<8+count*step || starts[i]>len || sizes[i]>len-starts[i]) fail("fat slice exceeds file")
            for(j=0;j<i;j++)
                if(starts[i]<starts[j]+sizes[j] && starts[j]<starts[i]+sizes[i]) fail("overlapping fat slices")
        }
        for(s=0;s<count;s++) slice(starts[s]+1,sizes[s])
    } else slice(1,len)
    if(check) exit (removed ? 2 : 0)
    if(length(data)!=len) fail("output length changed unexpectedly")
    printf "%s",data
    exit 0
}
