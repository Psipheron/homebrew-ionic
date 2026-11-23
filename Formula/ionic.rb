class Ionic < Formula
  desc "Statically-typed compiled language for data science and AI workloads"
  homepage "https://github.com/Psipheron/Ionic-Compiler"
  # No leading `v` here: Homebrew's audit forbids it (rubocops/version.rb) and
  # Version.new("v1.0.0") != Version.new("1.0.0"), so the keg would be named
  # `v1.0.0`.
  #
  # The release tag *does* carry the `v`, and this URL is the literal asset path,
  # so it keeps it. The updater writes this literal form too.
  version "1.0.0"
  license "MIT"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  url "https://github.com/Psipheron/Ionic-Compiler/releases/download/v1.0.0/ionic-v1.0.0-aarch64-apple-darwin.tar.gz"
  sha256 "104f84adbfb9768423f7d9fc9edc61f794eae74e9434cc55a9a38a8b03d918c5"

  def install
    # The self-hosted `ionic` locates its bundled standard library and C
    # runtime relative to its own executable directory ($IONIC_ROOT, set by
    # the C runtime from realpath(_NSGetExecutablePath)). Those assets must
    # therefore sit *next to* the real binary — not under `share/`.
    libexec.install "ionic"
    libexec.install "lib"
    libexec.install "src"          # the tarball's src/ holds only the C runtime
    bin.install_symlink libexec/"ionic"

    doc.install "README.md"
    doc.install "LICENSE"
  end

  def caveats
    <<~EOS
      The Ionic standard library and native runtime ship next to the compiler:

        #{opt_libexec}/lib
        #{opt_libexec}/src/ionic_model_runtime.c

      The `ionic` command is a symlink in #{HOMEBREW_PREFIX}/bin that points
      into libexec/. It resolves its own assets regardless of the current
      working directory, so you can compile from anywhere.

      ML backends are optional and are linked into the programs you compile,
      not into `ionic` itself. Install whichever you need:

        brew install mlx-c        # Apple-silicon GPU tensor runtime (mlx_* builtins)
        brew install onnxruntime  # ONNX inference + Piper TTS (piper_forward)

      Backends are linked only when a program actually references them, so a
      plain `ionic hello.ionic` stays dependency-free.

      MLX needs Apple silicon and Metal; it is unavailable on Intel Macs and on
      Linux. On those platforms `mlx_*` programs still compile and link, and
      report "MLX backend not compiled in" at runtime. ONNX Runtime is the only
      model-file backend on every target.

      Overrides, for a non-Homebrew prefix:
        IONIC_MLX_INCLUDE=/opt/mlx/include IONIC_MLX_LIB=/opt/mlx/lib \
            ionic model.ionic -o model

      To force a backend off (e.g. a half-installed mlx-c would fail to link):
        IONIC_NO_MLX=1 ionic model.ionic -o model
    EOS
  end

  test do
    (testpath/"hello.ionic").write <<~EOF
      fn main() -> int64 {
        print("hello from ionic");
        return 0;
      }
    EOF
    (testpath/"mlx_smoke.ionic").write <<~EOF
      fn main() -> int64 {
        if (mlx_available() == 0) { return 0; }
        let a = mlx_zeros([2, 2], 0);
        mlx_free(a);
        return 0;
      }
    EOF
    system bin/"ionic", "mlx_smoke.ionic", "-o", testpath/"mlx_smoke"
    system testpath/"mlx_smoke"

    testpath.cd do
      system bin/"ionic", "hello.ionic", "-o", testpath/"hello"
      assert_equal "hello from ionic", shell_output("#{testpath}/hello").strip

      (testpath/"std_test.ionic").write <<~EOF
        import std.math;
        fn main() -> int64 {
          print(str_concat("sqrt2=", float64_to_str(sqrt(4.0))));
          return 0;
        }
      EOF
      system bin/"ionic", "std_test.ionic", "-o", testpath/"std_test"
      assert_equal "sqrt2=2", shell_output("#{testpath}/std_test").strip
    end
  end
end
