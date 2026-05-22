import { readdirSync, readFileSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const apps = ['customer_app', 'provider_app'];

const violations = [];
const appSummaries = [];

for (const appName of apps) {
  const libRoot = resolve(root, 'apps', appName, 'lib');
  const dartFiles = listDartFiles(libRoot);
  const summary = {
    app: appName,
    dartFiles: dartFiles.length,
    firebaseImports: 0,
    supabaseImports: 0,
    presentationSupabaseImports: 0,
  };

  for (const file of dartFiles) {
    const source = readFileSync(file, 'utf8');
    const projectPath = normalize(relative(root, file));

    if (hasFirebaseReference(source)) {
      summary.firebaseImports += 1;
      violations.push({
        app: appName,
        file: projectPath,
        rule: 'firebase_removed',
        message: 'Firebase references are not allowed after the Supabase migration boundary was introduced.',
      });
    }

    if (source.includes('package:supabase_flutter/supabase_flutter.dart')) {
      summary.supabaseImports += 1;
      if (isPresentationOrScreenFile(projectPath)) {
        summary.presentationSupabaseImports += 1;
        violations.push({
          app: appName,
          file: projectPath,
          rule: 'no_direct_supabase_in_presentation',
          message:
            'Screens, controllers, and presentation providers must use repositories/use cases instead of importing Supabase directly.',
        });
      }
    }

    if (source.includes('Supabase.instance')) {
      violations.push({
        app: appName,
        file: projectPath,
        rule: 'no_supabase_singleton',
        message:
          'Use the injected supabaseClientProvider boundary instead of Supabase.instance so datasources remain testable.',
      });
    }
  }

  appSummaries.push(summary);
}

const result = {
  ok: violations.length === 0,
  apps: appSummaries,
  rules: [
    'Firebase imports/references are forbidden in Flutter apps.',
    'Supabase imports are allowed in core/data layers, not in main.dart or presentation layers.',
    'Use injected Supabase clients, not Supabase.instance.',
  ],
  violations,
};

console.log(JSON.stringify(result, null, 2));

if (!result.ok) {
  process.exitCode = 1;
}

function listDartFiles(directory) {
  const entries = readdirSync(directory, { withFileTypes: true });
  return entries.flatMap((entry) => {
    const fullPath = join(directory, entry.name);
    if (entry.isDirectory()) {
      return listDartFiles(fullPath);
    }
    return entry.isFile() && entry.name.endsWith('.dart') ? [fullPath] : [];
  });
}

function hasFirebaseReference(source) {
  return /\bFirebase[A-Za-z0-9_]*\b/.test(source) || /package:firebase_/i.test(source);
}

function isPresentationOrScreenFile(projectPath) {
  return (
    projectPath.endsWith('/lib/main.dart') ||
    projectPath.includes('/presentation/') ||
    projectPath.includes('/ui/') ||
    projectPath.includes('/screens/') ||
    projectPath.includes('/pages/')
  );
}

function normalize(value) {
  return value.replaceAll('\\', '/');
}
