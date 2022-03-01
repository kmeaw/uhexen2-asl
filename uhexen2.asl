state("h2") {}

init {
  print("[H2] Starting...");
  var h2 = modules.FirstOrDefault(x => x.ModuleName.ToLower() == "h2.exe" || x.ModuleName.ToLower() == "glh2.exe");
  if (h2 == null) {
    print("[H2] cannot find main module");
    Thread.Sleep(1000);
    throw new Exception();
  }
  var scanner = new SignatureScanner(game, h2.BaseAddress, h2.ModuleMemorySize);
  IntPtr fmtptr = scanner.Scan(new SigScanTarget(
    0, System.Text.Encoding.ASCII.GetBytes("Current level: %s [ %s ]\n")
  ));
  if (fmtptr == IntPtr.Zero) {
    print("[H2] cannot find fmt in main module");
    Thread.Sleep(1000);
    throw new Exception();
  }

  print("[H2] Found fmt pointer at 0x" + fmtptr.ToString("X"));

  bool found = false;
  int scan_offset = 0;
  IntPtr mapNamePtr = IntPtr.Zero;

  while (!found) {
    var offs = BitConverter.GetBytes(fmtptr.ToInt32());
    var fmtptrhex = BitConverter.ToString(offs).Replace("-", " ");

    scanner = new SignatureScanner(game, h2.BaseAddress + scan_offset, h2.ModuleMemorySize - scan_offset);
    var target = new SigScanTarget(
      10,
      "4C 8D 05 ?? ?? ?? ??", // lea r8, MapName
      "48 8D 15" // lea rdx, fmt
    );
    target.OnFound = (proc, _, ptr) => {
      int offset = proc.ReadValue<int>(ptr);
      IntPtr rdxptr = IntPtr.Add(ptr + 4, offset);
      if (rdxptr != fmtptr) {
	scan_offset = (int) (ptr.ToInt64() - h2.BaseAddress.ToInt64() + 4);
        return ptr;
      }
      found = true;
      offset = proc.ReadValue<int>(ptr - 7);
      return IntPtr.Add(ptr - 3, offset);
    };
    mapNamePtr = scanner.Scan(target);
    if (mapNamePtr == IntPtr.Zero) break;
  }
  if (!found) {
    print("[H2] cannot find fmt reference");
    Thread.Sleep(1000);
    throw new Exception();
  }
  print("[H2] DEBUG: found map name at " + mapNamePtr.ToString("X"));
  vars.mapName = new StringWatcher(new DeepPointer(mapNamePtr), ReadStringType.ASCII, 40);
  // vars.cltime = new MemoryWatcher<double>(new DeepPointer(mapNamePtr - 9720 + 1464));
  vars.intermission = new MemoryWatcher<int>(new DeepPointer(mapNamePtr - 9720 + 1412));
  
  vars.watchList = new MemoryWatcherList() {
    // vars.cltime,
    vars.mapName,
    vars.intermission
  };
  vars.watchList.UpdateAll(game);
  print("[H2] current map name is " + vars.mapName.Current);
}

update {
  vars.watchList.UpdateAll(game);

  if (vars.mapName.Changed) {
    current.map = vars.mapName.Current;
  }
}

split {
  return vars.mapName.Current != vars.mapName.Old;
}

isLoading {
  return vars.intermission.Current != 0;
}

reset {
  return vars.mapName.Current == "" && vars.mapName.Old != "";
}

start {
  return vars.mapName.Current != "";
}
