#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const desktopRoot = path.resolve(here, '..')
const repoRoot = path.resolve(desktopRoot, '..', '..')
const releaseRoot = path.join(desktopRoot, 'release')
const unpackedRoot = path.join(releaseRoot, 'win-unpacked')
const portableRoot = path.join(releaseRoot, 'Hermes-portable-win-x64')
const bundledAgentRoot = path.join(portableRoot, 'hermes-agent')
const portableHome = path.join(portableRoot, 'portable-home')
const sourceVenvRoot = path.join(repoRoot, '.venv')
const bundledVenvRoot = path.join(bundledAgentRoot, 'venv')
const bundledPythonRuntime = path.join(bundledAgentRoot, 'python-runtime')

function slash(p) {
  return p.split(path.sep).join('/')
}

function isUnder(candidate, parent) {
  const rel = path.relative(parent, candidate)
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel))
}

function copyDir(src, dest, filter) {
  cpSync(src, dest, {
    recursive: true,
    dereference: false,
    force: true,
    errorOnExist: false,
    filter
  })
}

function copyChildren(srcRoot, destRoot, filter) {
  mkdirSync(destRoot, { recursive: true })

  for (const entry of readdirSync(srcRoot)) {
    const src = path.join(srcRoot, entry)
    const dest = path.join(destRoot, entry)

    if (!filter(src)) {
      continue
    }

    cpSync(src, dest, {
      recursive: true,
      dereference: false,
      force: true,
      errorOnExist: false,
      filter
    })
  }
}

function repoFilter(src) {
  const rel = slash(path.relative(repoRoot, src))
  const base = path.basename(src)

  if (!rel) return true
  if (base === '.git' || base === 'node_modules' || base === '.venv' || base === 'venv') return false
  if (base === '__pycache__' || base === '.pytest_cache' || base === '.mypy_cache' || base === '.ruff_cache') return false
  if (rel === 'apps' || rel.startsWith('apps/')) return false
  if (rel === 'workspace' || rel.startsWith('workspace/')) return false
  if (rel === 'web/node_modules' || rel.startsWith('web/node_modules/')) return false
  if (rel === 'ui-tui/node_modules' || rel.startsWith('ui-tui/node_modules/')) return false
  return true
}

function venvFilter(src) {
  const rel = slash(path.relative(sourceVenvRoot, src))
  const base = path.basename(src)

  if (!rel) return true
  if (base === '__pycache__') return false
  if (rel.startsWith('Lib/site-packages/pip/_vendor/cachecontrol/caches/')) return false
  return true
}

function readVenvBasePythonRoot() {
  const cfgPath = path.join(sourceVenvRoot, 'pyvenv.cfg')
  const cfg = readFileSync(cfgPath, 'utf8')
  const match = cfg.match(/^home\s*=\s*(.+)$/m)
  if (!match) {
    throw new Error(`Cannot find "home =" in ${cfgPath}`)
  }
  return match[1].trim()
}

function pythonRuntimeFilter(src) {
  const rel = slash(path.relative(readVenvBasePythonRoot.cached, src))
  const base = path.basename(src)

  if (!rel) return true
  if (base === '__pycache__' || base === 'site-packages') return false
  if (rel === 'Scripts' || rel.startsWith('Scripts/')) return false
  if (rel.startsWith('Lib/site-packages/')) return false
  if (rel.startsWith('Lib/ensurepip/')) return false
  if (rel.startsWith('Lib/idlelib/')) return false
  if (rel.startsWith('Lib/test/')) return false
  if (rel.startsWith('Doc/')) return false
  if (rel.startsWith('tcl/')) return false
  return true
}

function writePortableHome() {
  mkdirSync(portableHome, { recursive: true })

  const sourceConfig = path.join(repoRoot, 'workspace', 'config.yaml')
  if (existsSync(sourceConfig)) {
    cpSync(sourceConfig, path.join(portableHome, 'config.yaml'))
  } else {
    writeFileSync(
      path.join(portableHome, 'config.yaml'),
      [
        'model:',
        '  provider: siliconflow',
        '  default: Qwen/Qwen3-32B',
        '  base_url: https://api.siliconflow.cn/v1',
        '  api_mode: chat_completions',
        '',
        'custom_providers:',
        '  siliconflow:',
        '    base_url: https://api.siliconflow.cn/v1',
        '    key_env: OPENAI_API_KEY',
        '    api_mode: chat_completions',
        '    model: Qwen/Qwen3-32B',
        ''
      ].join('\n'),
      'utf8'
    )
  }

  writeFileSync(
    path.join(portableHome, '.env'),
    [
      '# Hermes portable configuration.',
      '# Fill in your own key before using the packaged app.',
      '# For the default SiliconFlow config:',
      'OPENAI_API_KEY=',
      'OPENAI_BASE_URL=https://api.siliconflow.cn/v1',
      '',
      '# Optional providers:',
      '#OPENROUTER_API_KEY=',
      '#DASHSCOPE_API_KEY=',
      '#ANTHROPIC_API_KEY=',
      '#DEEPSEEK_API_KEY=',
      ''
    ].join('\n'),
    'utf8'
  )

  writeFileSync(
    path.join(portableRoot, 'README-PORTABLE.txt'),
    [
      'Hermes portable Windows package',
      '',
      'Run:',
      '  Hermes.exe',
      '',
      'Configuration lives inside:',
      '  portable-home\\config.yaml',
      '  portable-home\\.env',
      '',
      'Before first use, edit portable-home\\.env and fill your own API key.',
      '',
      'This package keeps Hermes data next to the executable and does not use',
      '%LOCALAPPDATA%\\hermes unless you explicitly set HERMES_HOME.',
      ''
    ].join('\r\n'),
    'utf8'
  )
}

function main() {
  if (!existsSync(path.join(unpackedRoot, 'Hermes.exe'))) {
    throw new Error(`Missing ${path.join(unpackedRoot, 'Hermes.exe')}; run npm run --workspace apps/desktop pack first.`)
  }
  if (!existsSync(path.join(sourceVenvRoot, 'Scripts', 'python.exe'))) {
    throw new Error('Missing .venv\\Scripts\\python.exe; run uv sync before making the portable package.')
  }

  rmSync(portableRoot, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 })
  mkdirSync(portableRoot, { recursive: true })

  console.log(`[portable] copying app shell -> ${portableRoot}`)
  copyDir(unpackedRoot, portableRoot, src => !isUnder(src, bundledAgentRoot) && !isUnder(src, portableHome))

  console.log(`[portable] copying Hermes source -> ${bundledAgentRoot}`)
  copyChildren(repoRoot, bundledAgentRoot, repoFilter)

  const basePythonRoot = readVenvBasePythonRoot()
  readVenvBasePythonRoot.cached = basePythonRoot

  console.log(`[portable] copying Python runtime -> ${bundledPythonRuntime}`)
  copyDir(basePythonRoot, bundledPythonRuntime, pythonRuntimeFilter)

  console.log(`[portable] copying Python venv -> ${bundledVenvRoot}`)
  copyDir(sourceVenvRoot, bundledVenvRoot, venvFilter)

  writePortableHome()
  console.log(`[portable] wrote ${portableRoot}`)
}

main()
