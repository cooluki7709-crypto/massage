import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const apps = [
  {
    name: 'customer_app',
    pubspecPath: 'apps/customer_app/pubspec.yaml',
    rootGradlePath: 'apps/customer_app/android/build.gradle.kts',
    appGradlePath: 'apps/customer_app/android/app/build.gradle.kts',
    configPath: 'apps/customer_app/android/app/google-services.json',
  },
  {
    name: 'provider_app',
    pubspecPath: 'apps/provider_app/pubspec.yaml',
    rootGradlePath: 'apps/provider_app/android/build.gradle.kts',
    appGradlePath: 'apps/provider_app/android/app/build.gradle.kts',
    configPath: 'apps/provider_app/android/app/google-services.json',
  },
];

const optional = process.argv.includes('--optional');
const result = {
  ok: true,
  optional,
  mode: 'firebase_removed',
  apps: [],
};

for (const app of apps) {
  const pubspecSource = readIfExists(app.pubspecPath);
  const rootGradleSource = readIfExists(app.rootGradlePath);
  const appGradleSource = readIfExists(app.appGradlePath);

  const appResult = {
    name: app.name,
    hasFirebasePackages: /firebase_core|firebase_messaging/.test(pubspecSource),
    hasGoogleServicesPlugin: /com\.google\.gms\.google-services/.test(
      `${rootGradleSource}\n${appGradleSource}`,
    ),
    hasGoogleServicesConfig: existsSync(resolve(app.configPath)),
  };

  if (
    appResult.hasFirebasePackages ||
    appResult.hasGoogleServicesPlugin ||
    appResult.hasGoogleServicesConfig
  ) {
    result.ok = false;
  }

  result.apps.push(appResult);
}

console.log(JSON.stringify(result, null, 2));

if (!result.ok && !optional) {
  process.exitCode = 1;
}

function readIfExists(path) {
  const filePath = resolve(path);
  return existsSync(filePath) ? readFileSync(filePath, 'utf8') : '';
}
