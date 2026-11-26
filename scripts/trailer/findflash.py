import subprocess, sys, numpy as np
for name in sys.argv[1:]:
    w, h = 64, 24
    raw = subprocess.run(['ffmpeg','-v','error','-i',name,'-vf',f'scale={w}:{h}','-f','rawvideo','-pix_fmt','rgb24','-'],capture_output=True).stdout
    fr = np.frombuffer(raw, np.uint8).reshape(-1, h, w, 3).astype(float)
    # magenta: R high, G low, B high across the whole frame
    score = (fr[...,0] > 200).mean((1,2)) * (fr[...,1] < 60).mean((1,2)) * (fr[...,2] > 200).mean((1,2))
    i = int(score.argmax())
    pts = subprocess.run(['ffprobe','-v','error','-select_streams','v','-show_entries','frame=pts_time','-of','csv=p=0',name],capture_output=True,text=True).stdout.split()
    print(name, i, round(score[i],3), pts[i] if i < len(pts) else '?', len(fr))
