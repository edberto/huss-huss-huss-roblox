import subprocess, sys, numpy as np
for name in sys.argv[1:]:
    raw = subprocess.run(['ffmpeg','-v','error','-i',name,'-vn','-ac','1','-ar','8000','-f','s16le','-'],capture_output=True).stdout
    a = np.frombuffer(raw, np.int16).astype(float)/32768
    hop = 80  # 10 ms
    e = np.array([np.sqrt((a[i:i+hop]**2).mean()) for i in range(0, len(a)-hop, hop)])
    d = np.diff(e, prepend=0)
    thr = d.max()*0.35
    peaks = [i for i in range(1,len(d)-1) if d[i]>thr and d[i]>=d[i-1] and d[i]>=d[i+1]]
    out=[]
    for p in peaks:
        if not out or p-out[-1]>15: out.append(p)
    print(name, [round(p*0.01,2) for p in out])
