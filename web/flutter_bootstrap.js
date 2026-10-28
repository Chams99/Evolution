{{flutter_js}}
{{flutter_build_config}}

// Tells the loading screen in index.html which step the start-up is on.
function loadingStep(step) {
  if (window.evolutionLoading) window.evolutionLoading(step);
}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    loadingStep(1);
    const appRunner = await engineInitializer.initializeEngine();
    loadingStep(2);
    await appRunner.runApp();
  },
});
