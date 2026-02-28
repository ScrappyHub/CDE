using System;
using System.IO;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;

namespace CDE.Runtime.Engine;

public abstract class CdeGame : Game
{
    // CDE_KERNEL_OVERLAY_V3B
    private GameplayBridge? _kernel;
    private KernelOverlayComponent? _kernelOverlay;
    private readonly GraphicsDeviceManager _gdm;

    protected CdeGame()
    {
        _gdm = new GraphicsDeviceManager(this);
        IsMouseVisible = true;
        Content.RootDirectory = "Content";
    }

    protected GraphicsDeviceManager GraphicsManager => _gdm;

    protected override void Initialize()
    {
        EnsureKernelOverlay();
        base.Initialize();
        Window.AllowUserResizing = true;
    }

    protected void ExitIfRequested()
    {
        var kb = Keyboard.GetState();
        if (kb.IsKeyDown(Keys.Escape)) Exit();
    }

    private static string FindRepoRoot(string start)
    {
        var d = new DirectoryInfo(start);
        for (int i = 0; i < 12 && d != null; i++)
        {
            var sln = Path.Combine(d.FullName, "CDE.sln");
            if (File.Exists(sln)) return d.FullName;
            d = d.Parent;
        }
        return Directory.GetCurrentDirectory();
    }

    private void EnsureKernelOverlay()
    {
        if (_kernelOverlay != null) return;
        var root = FindRepoRoot(AppContext.BaseDirectory);
        _kernel = new GameplayBridge();
        _kernel.LoadFromRepoRoot(root);
        _kernelOverlay = new KernelOverlayComponent(this, _kernel);
        Components.Add(_kernelOverlay);
    }
}

