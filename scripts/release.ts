import { createHash } from 'crypto'
import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'fs'
import { basename, join, resolve } from 'path'

type ArchiveType = 'tar.gz' | 'zip'

type ReleaseTarget = {
  id: string
  bunTarget: string
  archiveType: ArchiveType
  archiveName: string
  binaryName: string
  platform: 'linux' | 'macos' | 'windows'
  arch: 'x64' | 'arm64'
  libc?: 'glibc' | 'musl'
}

const rootDir = resolve(import.meta.dir, '..')
const distDir = join(rootDir, 'dist', 'release')
const pkg = JSON.parse(readFileSync(join(rootDir, 'package.json'), 'utf8')) as {
  version: string
  name: string
}
const args = process.argv.slice(2)

function getOption(name: string): string | null {
  const prefix = `--${name}=`
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]
    if (arg === `--${name}`) {
      return args[i + 1] ?? null
    }
    if (arg.startsWith(prefix)) {
      return arg.slice(prefix.length)
    }
  }
  return null
}

function runOrThrow(cmd: string[], cwd = rootDir): string {
  const proc = Bun.spawnSync({
    cmd,
    cwd,
    stdout: 'pipe',
    stderr: 'pipe',
  })

  const stdout = new TextDecoder().decode(proc.stdout)
  const stderr = new TextDecoder().decode(proc.stderr)

  if (proc.exitCode !== 0) {
    if (stdout.trim()) {
      console.log(stdout)
    }
    if (stderr.trim()) {
      console.error(stderr)
    }
    throw new Error(`Command failed (${proc.exitCode}): ${cmd.join(' ')}`)
  }

  if (stdout.trim()) {
    console.log(stdout.trim())
  }
  return stdout.trim()
}

function sha256(filePath: string): string {
  const hash = createHash('sha256')
  hash.update(readFileSync(filePath))
  return hash.digest('hex')
}

function copyIfExists(source: string, destination: string): void {
  if (existsSync(source)) {
    cpSync(source, destination)
  }
}

function psSingleQuote(value: string): string {
  return `'${value.replaceAll("'", "''")}'`
}

function createArchive(stageParent: string, archivePath: string, archiveType: ArchiveType): void {
  if (existsSync(archivePath)) {
    rmSync(archivePath, { force: true })
  }

  if (archiveType === 'zip') {
    if (process.platform === 'win32') {
      runOrThrow([
        'powershell',
        '-NoProfile',
        '-Command',
        [
          `$archive = ${psSingleQuote(archivePath)}`,
          'if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }',
          `Compress-Archive -LiteralPath ${psSingleQuote(join(stageParent, 'free-code'))} -DestinationPath $archive -Force`,
        ].join('; '),
      ])
      return
    }

    runOrThrow(['zip', '-qr', archivePath, 'free-code'], stageParent)
    return
  }

  runOrThrow(['tar', '-czf', archivePath, 'free-code'], stageParent)
}

const targets: ReleaseTarget[] = [
  {
    id: 'linux-x64',
    bunTarget: 'bun-linux-x64',
    archiveType: 'tar.gz',
    archiveName: 'free-code-linux-x64.tar.gz',
    binaryName: 'free-code',
    platform: 'linux',
    arch: 'x64',
    libc: 'glibc',
  },
  {
    id: 'linux-arm64',
    bunTarget: 'bun-linux-arm64',
    archiveType: 'tar.gz',
    archiveName: 'free-code-linux-arm64.tar.gz',
    binaryName: 'free-code',
    platform: 'linux',
    arch: 'arm64',
    libc: 'glibc',
  },
  {
    id: 'linux-x64-musl',
    bunTarget: 'bun-linux-x64-musl',
    archiveType: 'tar.gz',
    archiveName: 'free-code-linux-x64-musl.tar.gz',
    binaryName: 'free-code',
    platform: 'linux',
    arch: 'x64',
    libc: 'musl',
  },
  {
    id: 'linux-arm64-musl',
    bunTarget: 'bun-linux-arm64-musl',
    archiveType: 'tar.gz',
    archiveName: 'free-code-linux-arm64-musl.tar.gz',
    binaryName: 'free-code',
    platform: 'linux',
    arch: 'arm64',
    libc: 'musl',
  },
  {
    id: 'macos-x64',
    bunTarget: 'bun-darwin-x64',
    archiveType: 'tar.gz',
    archiveName: 'free-code-macos-x64.tar.gz',
    binaryName: 'free-code',
    platform: 'macos',
    arch: 'x64',
  },
  {
    id: 'macos-arm64',
    bunTarget: 'bun-darwin-arm64',
    archiveType: 'tar.gz',
    archiveName: 'free-code-macos-arm64.tar.gz',
    binaryName: 'free-code',
    platform: 'macos',
    arch: 'arm64',
  },
  {
    id: 'windows-x64',
    bunTarget: 'bun-windows-x64',
    archiveType: 'zip',
    archiveName: 'free-code-windows-x64.zip',
    binaryName: 'free-code.exe',
    platform: 'windows',
    arch: 'x64',
  },
  {
    id: 'windows-arm64',
    bunTarget: 'bun-windows-arm64',
    archiveType: 'zip',
    archiveName: 'free-code-windows-arm64.zip',
    binaryName: 'free-code.exe',
    platform: 'windows',
    arch: 'arm64',
  },
]

const onlyTargets = getOption('targets')
const selectedTargets =
  onlyTargets === null
    ? targets
    : targets.filter((target) => onlyTargets.split(',').map((item) => item.trim()).includes(target.id))

if (selectedTargets.length === 0) {
  throw new Error('No release targets selected. Use --targets with one or more valid target ids.')
}

const gitSha = runOrThrow(['git', 'rev-parse', '--short=8', 'HEAD']).trim() || 'unknown'
const generatedAt = new Date().toISOString()

rmSync(distDir, { recursive: true, force: true })
mkdirSync(distDir, { recursive: true })

const manifestTargets: Array<Record<string, unknown>> = []
const checksums: string[] = []

for (const target of selectedTargets) {
  const buildDir = join(distDir, 'build', target.id)
  const stageParent = join(distDir, 'staging', target.id)
  const stageDir = join(stageParent, 'free-code')
  const outputPath = join(buildDir, target.binaryName)
  const archivePath = join(distDir, target.archiveName)

  rmSync(buildDir, { recursive: true, force: true })
  rmSync(stageParent, { recursive: true, force: true })
  mkdirSync(buildDir, { recursive: true })
  mkdirSync(stageDir, { recursive: true })

  console.log(`\n==> Building ${target.id} (${target.bunTarget})`)
  runOrThrow([
    process.execPath,
    'run',
    './scripts/build.ts',
    '--compile',
    '--feature-set=dev-full',
    `--target=${target.bunTarget}`,
    `--outfile=${outputPath}`,
  ])

  const builtBinaryPath =
    existsSync(outputPath)
      ? outputPath
      : existsSync(`${outputPath}.exe`)
        ? `${outputPath}.exe`
        : null

  if (builtBinaryPath === null) {
    throw new Error(`Expected compiled binary was not created for ${target.id}`)
  }

  cpSync(builtBinaryPath, join(stageDir, target.binaryName))
  copyIfExists(join(rootDir, 'README.md'), join(stageDir, 'README.md'))
  copyIfExists(join(rootDir, 'FEATURES.md'), join(stageDir, 'FEATURES.md'))
  writeFileSync(
    join(stageDir, 'VERSION.txt'),
    [
      `version=${pkg.version}`,
      `git_sha=${gitSha}`,
      `target=${target.id}`,
      `bun_target=${target.bunTarget}`,
      `generated_at=${generatedAt}`,
    ].join('\n') + '\n',
    'utf8',
  )

  createArchive(stageParent, archivePath, target.archiveType)

  const hash = sha256(archivePath)
  const archiveStat = statSync(archivePath)
  checksums.push(`${hash}  ${basename(archivePath)}`)
  manifestTargets.push({
    id: target.id,
    platform: target.platform,
    arch: target.arch,
    libc: target.libc ?? null,
    bunTarget: target.bunTarget,
    archive: basename(archivePath),
    archiveType: target.archiveType,
    binary: target.binaryName,
    sha256: hash,
    size: archiveStat.size,
  })
}

writeFileSync(join(distDir, 'checksums.txt'), checksums.join('\n') + '\n', 'utf8')
writeFileSync(
  join(distDir, 'manifest.json'),
  JSON.stringify(
    {
      name: 'free-code',
      version: pkg.version,
      sourcePackage: pkg.name,
      gitSha,
      generatedAt,
      targets: manifestTargets,
    },
    null,
    2,
  ) + '\n',
  'utf8',
)

console.log(`\nRelease artifacts written to ${distDir}`)
