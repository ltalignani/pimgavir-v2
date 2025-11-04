#!/usr/bin/env python3
"""
DRAM FTP to HTTPS Patcher

This script patches DRAM's database_handler.py to replace FTP URLs with HTTPS URLs.
This is necessary when working on clusters that block FTP protocol.

Usage:
    python patch_dram_https.py [--dram-path PATH] [--backup] [--dry-run]

Options:
    --dram-path PATH    Path to DRAM installation (auto-detected if not provided)
    --backup           Create backup before patching (default: True)
    --dry-run          Show changes without applying them
    --restore          Restore from backup
"""

import os
import sys
import re
import shutil
import argparse
from pathlib import Path
from datetime import datetime


class DRAMPatcher:
    """Patches DRAM source code to use HTTPS instead of FTP"""

    # URL replacements (FTP -> HTTPS)
    URL_REPLACEMENTS = {
        # KOfam and KEGG databases
        r'ftp://ftp\.genome\.jp/': 'https://www.genome.jp/ftp/',

        # Pfam database
        r'ftp://ftp\.ebi\.ac\.uk/pub/databases/Pfam/': 'https://ftp.ebi.ac.uk/pub/databases/Pfam/',

        # UniProt/UniRef databases
        r'ftp://ftp\.uniprot\.org/pub/databases/uniprot/': 'https://ftp.uniprot.org/pub/databases/uniprot/',

        # MEROPS peptidase database
        r'ftp://ftp\.ebi\.ac\.uk/pub/databases/merops/': 'https://ftp.ebi.ac.uk/pub/databases/merops/',

        # dbCAN (if it uses FTP)
        r'ftp://bcb\.unl\.edu/dbCAN2/': 'https://bcb.unl.edu/dbCAN2/',

        # VOG database (if it uses FTP)
        r'ftp://fileshare\.csb\.univie\.ac\.at/vog/': 'https://fileshare.csb.univie.ac.at/vog/',
    }

    # Bug fixes (GitHub issues)
    BUG_FIXES = {
        # VOG HMM path bug - https://github.com/metagenome-atlas/atlas/issues/718
        r"path\.join\(hmm_dir, 'VOG\*\.hmm'\)": "path.join(hmm_dir, 'hmm', 'VOG*.hmm')",
    }

    def __init__(self, dram_path=None):
        """Initialize patcher with DRAM installation path"""
        self.dram_path = self._find_dram_path(dram_path)
        self.handler_file = self.dram_path / 'database_processing.py'  # Changed: actual file with download functions
        self.backup_dir = Path.home() / 'DRAM_backups'

    def _find_dram_path(self, provided_path):
        """Find DRAM installation path"""
        if provided_path:
            path = Path(provided_path)
            if path.exists():
                return path
            raise FileNotFoundError(f"Provided DRAM path does not exist: {provided_path}")

        # Try to auto-detect
        try:
            import mag_annotator
            auto_path = Path(mag_annotator.__file__).parent
            print(f"Auto-detected DRAM installation: {auto_path}")
            return auto_path
        except ImportError:
            raise ImportError(
                "Could not auto-detect DRAM installation. "
                "Please provide path with --dram-path option"
            )

    def create_backup(self):
        """Create backup of original file"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_path = self.backup_dir / timestamp
        backup_path.mkdir(parents=True, exist_ok=True)

        backup_file = backup_path / 'database_processing.py'
        shutil.copy2(self.handler_file, backup_file)

        # Also create .original backup if it doesn't exist
        original_backup = self.handler_file.with_suffix('.py.original')
        if not original_backup.exists():
            shutil.copy2(self.handler_file, original_backup)

        print(f"✓ Backup created: {backup_file}")
        print(f"✓ Original saved: {original_backup}")
        return backup_file

    def restore_backup(self):
        """Restore from .original backup"""
        original_backup = self.handler_file.with_suffix('.py.original')
        if not original_backup.exists():
            print("✗ No backup found (.py.original)")
            return False

        shutil.copy2(original_backup, self.handler_file)
        print(f"✓ Restored from: {original_backup}")
        return True

    def analyze_file(self):
        """Analyze file and find FTP URLs"""
        with open(self.handler_file, 'r') as f:
            content = f.read()

        # Find all FTP URLs
        ftp_pattern = re.compile(r'ftp://[^\s\'"]+')
        ftp_urls = ftp_pattern.findall(content)

        if ftp_urls:
            print(f"\n📊 Found {len(ftp_urls)} FTP URLs:")
            for i, url in enumerate(set(ftp_urls), 1):
                print(f"  {i}. {url}")
        else:
            print("✓ No FTP URLs found")

        return ftp_urls

    def apply_patch(self, dry_run=False):
        """Apply URL replacements and bug fixes"""
        with open(self.handler_file, 'r') as f:
            original_content = f.read()

        modified_content = original_content
        changes_made = []

        # Apply URL replacements
        for ftp_pattern, https_replacement in self.URL_REPLACEMENTS.items():
            matches = re.findall(ftp_pattern, modified_content)
            if matches:
                modified_content = re.sub(ftp_pattern, https_replacement, modified_content)
                changes_made.append(('URL', ftp_pattern, https_replacement, len(matches)))

        # Apply bug fixes
        for bug_pattern, bug_fix in self.BUG_FIXES.items():
            matches = re.findall(bug_pattern, modified_content)
            if matches:
                modified_content = re.sub(bug_pattern, bug_fix, modified_content)
                changes_made.append(('BUG', bug_pattern, bug_fix, len(matches)))

        if not changes_made:
            print("✓ No changes needed - file already patched")
            return False

        # Show changes
        print("\n🔧 Changes to be applied:")
        for change_type, pattern, replacement, count in changes_made:
            if change_type == 'URL':
                print(f"  • URL: {pattern}")
                print(f"    → {replacement}")
                print(f"    ({count} occurrence{'s' if count > 1 else ''})")
            elif change_type == 'BUG':
                print(f"  • Bug Fix: {pattern}")
                print(f"    → {replacement}")
                print(f"    ({count} occurrence{'s' if count > 1 else ''})")

        if dry_run:
            print("\n[DRY RUN] No changes written to file")
            return True

        # Write modified content
        with open(self.handler_file, 'w') as f:
            f.write(modified_content)

        print(f"\n✓ Patch applied successfully to: {self.handler_file}")
        return True

    def verify_patch(self):
        """Verify that patch was applied correctly"""
        with open(self.handler_file, 'r') as f:
            content = f.read()

        # Check for remaining FTP URLs
        ftp_pattern = re.compile(r'ftp://[^\s\'"]+')
        remaining_ftp = ftp_pattern.findall(content)

        # Check for HTTPS URLs
        https_pattern = re.compile(r'https://[^\s\'"]+')
        https_urls = https_pattern.findall(content)

        print("\n✅ Verification Results:")
        print(f"  • Remaining FTP URLs: {len(remaining_ftp)}")
        if remaining_ftp:
            print("    Warning: Some FTP URLs remain:")
            for url in set(remaining_ftp):
                print(f"      - {url}")

        print(f"  • HTTPS URLs found: {len(https_urls)}")

        if len(remaining_ftp) == 0:
            print("\n✓ Patch verification PASSED - No FTP URLs remain")
            return True
        else:
            print("\n⚠ Patch verification WARNING - Some FTP URLs remain")
            print("  These may need manual review")
            return False


def main():
    parser = argparse.ArgumentParser(
        description='Patch DRAM to use HTTPS instead of FTP for database downloads',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Auto-detect and patch with backup
  python patch_dram_https.py

  # Dry run to see changes
  python patch_dram_https.py --dry-run

  # Specify DRAM path manually
  python patch_dram_https.py --dram-path ~/miniconda3/envs/pimgavir_viralgenomes/lib/python3.9/site-packages/mag_annotator

  # Restore from backup
  python patch_dram_https.py --restore
        """
    )

    parser.add_argument(
        '--dram-path',
        type=str,
        help='Path to DRAM mag_annotator directory (auto-detected if not provided)'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show changes without applying them'
    )

    parser.add_argument(
        '--no-backup',
        action='store_true',
        help='Skip creating backup (not recommended)'
    )

    parser.add_argument(
        '--restore',
        action='store_true',
        help='Restore from backup (.py.original)'
    )

    parser.add_argument(
        '--verify-only',
        action='store_true',
        help='Only verify current state, do not patch'
    )

    args = parser.parse_args()

    try:
        # Initialize patcher
        print("🔍 Initializing DRAM patcher...")
        patcher = DRAMPatcher(args.dram_path)
        print(f"✓ DRAM installation found: {patcher.dram_path}")
        print(f"✓ Target file: {patcher.handler_file}")

        # Restore mode
        if args.restore:
            print("\n♻️  Restoring from backup...")
            if patcher.restore_backup():
                print("✓ Restore complete")
                patcher.verify_patch()
            return 0

        # Verify only mode
        if args.verify_only:
            print("\n🔍 Analyzing current state...")
            patcher.analyze_file()
            patcher.verify_patch()
            return 0

        # Normal patch mode
        print("\n🔍 Analyzing file for FTP URLs...")
        ftp_urls = patcher.analyze_file()

        if not ftp_urls:
            print("✓ File appears already patched or contains no FTP URLs")
            return 0

        # Create backup
        if not args.no_backup:
            print("\n💾 Creating backup...")
            patcher.create_backup()

        # Apply patch
        print("\n🔧 Applying patch...")
        if patcher.apply_patch(dry_run=args.dry_run):
            if not args.dry_run:
                patcher.verify_patch()
                print("\n" + "="*60)
                print("PATCH COMPLETE!")
                print("="*60)
                print("\nNext steps:")
                print("1. Test DRAM setup:")
                print("   DRAM-setup.py prepare_databases --output_dir ./dram-db --skip_uniref --threads 8")
                print("\n2. Verify configuration:")
                print("   DRAM-setup.py print_config")
                print("\n3. If issues occur, restore backup:")
                print(f"   python {sys.argv[0]} --restore")

        return 0

    except Exception as e:
        print(f"\n✗ Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
