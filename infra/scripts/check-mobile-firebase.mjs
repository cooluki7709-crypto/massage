import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const apps = [
  {
    name: 'customer_app',
    configPath: 'apps/customer_app/android/app/google-services.json',
    gradlePath: 'apps/customer_app/android/app/build.gradle.kts',
    expectedApplicationId: 'com.massagevn.customer.customer_app',
  },
  {
    name: 'provider_app',
    configPath: 'apps/provider_app/android/app/google-services.json',
    gradlePath: 'apps/provider_app/android/app/build.gradle.kts',
    expectedApplicationId: 'com.massagevn.provider.provider_app',
  },
];

const optional = process.argv.includes('--optional');
const result = {
  ok: true,
  optional,
  apps: [],
};

for (const app of apps) {
  const configFile = resolve(app.configPath);
  const gradleFile = resolve(app.gradlePath);
  const gradleSource = readFileSync(gradleFile, 'utf8');
  const hasGoogleServicesPlugin = gradleSource.includes('com.google.gms.google-services');
  const hasConfig = existsSync(configFile);
  let packageName = null;
  let packageMatches = false;

  if (hasConfig) {
    const config = JSON.parse(readFileSync(configFile, 'utf8'));
    packageName = config?.client?.[0]?.client_info?.android_client_info?.package_name ?? null;
    packageMatches = packageName === app.expectedApplicationId;
  }

  const appResult = {
    name: app.name,
    hasGoogleServicesPlugin,
    hasConfig,
    expectedApplicationId: app.expectedApplicationId,
    packageName,
    packageMatches: hasConfig ? packageMatches : false,
  };

  if (!hasGoogleServicesPlugin || !hasConfig || (hasConfig && !packageMatches)) {
    result.ok = false;
  }

  result.apps.push(appResult);
}

console.log(JSON.stringify(result, null, 2));

if (!result.ok && !optional) {
  process.exitCode = 1;
}
