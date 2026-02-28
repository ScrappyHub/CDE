using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

namespace CDE.Runtime.Engine.Graphics;

/// <summary>
/// PixelPerfectRenderer:
/// - Draw world into a fixed virtual RenderTarget2D
/// - Upscale to backbuffer using integer scale only
/// - Letterbox remaining space
/// - Point sampling only
/// </summary>
public sealed class PixelPerfectRenderer : System.IDisposable
{
    private readonly GraphicsDevice _gd;
    private RenderTarget2D? _rt;

    public int VirtualWidth { get; private set; }
    public int VirtualHeight { get; private set; }

    public int IntegerScale { get; private set; } = 1;
    public Rectangle DestinationRect { get; private set; }

    public PixelPerfectRenderer(GraphicsDevice gd, int virtualWidth, int virtualHeight)
    {
        _gd = gd;
        SetVirtualResolution(virtualWidth, virtualHeight);
    }

    public void SetVirtualResolution(int w, int h)
    {
        if (w <= 0 || h <= 0) throw new System.ArgumentOutOfRangeException(nameof(w));
        VirtualWidth = w;
        VirtualHeight = h;

        _rt?.Dispose();
        _rt = new RenderTarget2D(
            _gd,
            VirtualWidth,
            VirtualHeight,
            false,
            SurfaceFormat.Color,
            DepthFormat.None,
            0,
            RenderTargetUsage.DiscardContents
        );

        RecalculateDestination(_gd.PresentationParameters.BackBufferWidth, _gd.PresentationParameters.BackBufferHeight);
    }

    public void OnBackBufferResized(int backBufferW, int backBufferH)
        => RecalculateDestination(backBufferW, backBufferH);

    private void RecalculateDestination(int backBufferW, int backBufferH)
    {
        if (backBufferW <= 0 || backBufferH <= 0) return;

        var sx = backBufferW / VirtualWidth;
        var sy = backBufferH / VirtualHeight;
        var scale = System.Math.Max(1, System.Math.Min(sx, sy));
        IntegerScale = scale;

        var dstW = VirtualWidth * scale;
        var dstH = VirtualHeight * scale;
        var x = (backBufferW - dstW) / 2;
        var y = (backBufferH - dstH) / 2;
        DestinationRect = new Rectangle(x, y, dstW, dstH);
    }

    public void BeginVirtual()
    {
        if (_rt == null) throw new System.InvalidOperationException("RenderTarget not initialized.");
        _gd.SetRenderTarget(_rt);
        _gd.Clear(Color.Transparent);
    }

    public void EndVirtualAndBlitToBackbuffer(SpriteBatch sb, Color clearColor)
    {
        if (_rt == null) throw new System.InvalidOperationException("RenderTarget not initialized.");

        _gd.SetRenderTarget(null);
        _gd.Clear(clearColor);

        sb.Begin(
            SpriteSortMode.Deferred,
            BlendState.AlphaBlend,
            SamplerState.PointClamp,
            DepthStencilState.None,
            RasterizerState.CullNone
        );

        sb.Draw(_rt, DestinationRect, Color.White);
        sb.End();
    }

    public void Dispose()
    {
        _rt?.Dispose();
        _rt = null;
    }
}
