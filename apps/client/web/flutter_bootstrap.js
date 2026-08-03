{{flutter_js}}
{{flutter_build_config}}

(async () => {
  if ('serviceWorker' in navigator) {
    try {
      await navigator.serviceWorker.register('sprache_service_worker.js');
    } catch (error) {
      console.warn('Sprache offline cache registration failed:', error);
    }
  }
  await _flutter.loader.load();
})();
