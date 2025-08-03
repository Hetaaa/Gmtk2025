#!/usr/bin/env python3
"""
Skrypt do zmniejszania rozdzielczości grafik 3x dla optymalizacji gier.
Obsługuje PNG, JPG, JPEG, BMP, TIFF i inne popularne formaty.
"""

import os
import sys
from pathlib import Path
from PIL import Image, ImageFile
import shutil
import argparse

# Umożliwia przetwarzanie uszkodzonych obrazów
ImageFile.LOAD_TRUNCATED_IMAGES = True

# Obsługiwane formaty obrazów
SUPPORTED_FORMATS = {'.png', '.jpg', '.jpeg', '.bmp', '.tiff', '.tif', '.webp', '.gif'}

def get_file_size(filepath):
    """Zwraca rozmiar pliku w bajtach."""
    return os.path.getsize(filepath)

def format_size(size_bytes):
    """Formatuje rozmiar pliku w czytelny sposób."""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    else:
        return f"{size_bytes / (1024 * 1024):.1f} MB"

def get_optimal_resampling(scale_factor):
    """
    Wybiera optymalny algorytm resamplingu w zależności od skali.
    Dla zmniejszania używa LANCZOS dla najlepszej jakości.
    """
    if scale_factor < 1:
        return Image.Resampling.LANCZOS  # Najlepsza jakość dla zmniejszania
    else:
        return Image.Resampling.BICUBIC   # Dobra jakość dla powiększania

def resize_image(input_path, output_path=None, scale_factor=1/3, quality=95):
    """
    Zmienia rozmiar obrazu z zachowaniem proporcji.
    
    Args:
        input_path: ścieżka do pliku wejściowego
        output_path: ścieżka do pliku wyjściowego (None = nadpisz oryginalny)
        scale_factor: współczynnik skalowania (1/3 = 3x mniejszy)
        quality: jakość JPEG (1-100, tylko dla JPG)
    """
    if output_path is None:
        output_path = input_path
    
    try:
        with Image.open(input_path) as img:
            # Pobierz oryginalne wymiary
            original_width, original_height = img.size
            
            # Oblicz nowe wymiary
            new_width = int(original_width * scale_factor)
            new_height = int(original_height * scale_factor)
            
            # Minimalne wymiary (żeby obraz nie był za mały)
            min_size = 8
            new_width = max(new_width, min_size)
            new_height = max(new_height, min_size)
            
            # Zmień rozmiar z optymalnym algorytmem
            resampling = get_optimal_resampling(scale_factor)
            resized_img = img.resize((new_width, new_height), resampling)
            
            # Przygotuj parametry zapisu
            save_kwargs = {}
            
            # Dla JPEG ustaw jakość
            if output_path.lower().endswith(('.jpg', '.jpeg')):
                save_kwargs['quality'] = quality
                save_kwargs['optimize'] = True
            
            # Dla PNG optymalizuj
            elif output_path.lower().endswith('.png'):
                save_kwargs['optimize'] = True
                # Zachowaj przezroczystość
                if img.mode in ('RGBA', 'LA') or 'transparency' in img.info:
                    save_kwargs['format'] = 'PNG'
            
            # Zapisz przeskalowany obraz
            resized_img.save(output_path, **save_kwargs)
            
            return (original_width, original_height), (new_width, new_height)
            
    except Exception as e:
        print(f"Błąd podczas zmiany rozmiaru {input_path}: {e}")
        return None

def process_image_file(filepath, scale_factor=1/3, keep_backup=False, quality=95):
    """
    Przetwarza pojedynczy plik graficzny.
    """
    original_size = get_file_size(filepath)
    backup_path = f"{filepath}.backup"
    
    # Utwórz kopię zapasową
    shutil.copy2(filepath, backup_path)
    
    try:
        # Zmień rozmiar obrazu
        result = resize_image(filepath, scale_factor=scale_factor, quality=quality)
        
        if result is None:
            # Przywróć oryginalny plik w przypadku błędu
            shutil.move(backup_path, filepath)
            return 0
        
        original_dims, new_dims = result
        new_size = get_file_size(filepath)
        
        # Oblicz oszczędności
        size_reduction = ((original_size - new_size) / original_size) * 100
        
        print(f"✓ {filepath}")
        print(f"  Wymiary: {original_dims[0]}x{original_dims[1]} → {new_dims[0]}x{new_dims[1]}")
        print(f"  Rozmiar: {format_size(original_size)} → {format_size(new_size)} "
              f"(-{size_reduction:.1f}%)")
        
        # Zarządzaj kopią zapasową
        if keep_backup:
            print(f"  Kopia zapasowa: {backup_path}")
        else:
            os.remove(backup_path)
        
        return original_size - new_size
        
    except Exception as e:
        print(f"✗ Błąd podczas przetwarzania {filepath}: {e}")
        # Przywróć oryginalny plik
        if os.path.exists(backup_path):
            shutil.move(backup_path, filepath)
        return 0

def find_image_files(directory, exclude_dirs=None):
    """
    Znajduje wszystkie pliki graficzne w podanym katalogu.
    """
    if exclude_dirs is None:
        exclude_dirs = {'.git', 'node_modules', 'venv', '__pycache__', '.vscode', '.idea'}
    
    image_files = []
    for root, dirs, files in os.walk(directory):
        # Pomiń wykluczone katalogi
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        for file in files:
            file_ext = Path(file).suffix.lower()
            if file_ext in SUPPORTED_FORMATS:
                image_files.append(os.path.join(root, file))
    
    return image_files

def main():
    parser = argparse.ArgumentParser(
        description='Zmniejsza rozdzielczość grafik dla optymalizacji gier'
    )
    parser.add_argument('directory', nargs='?', default='.', 
                       help='Katalog do skanowania (domyślnie bieżący)')
    parser.add_argument('--scale', '-s', type=float, default=1/3,
                       help='Współczynnik skalowania (domyślnie 1/3 = 3x mniejszy)')
    parser.add_argument('--keep-backups', '-b', action='store_true',
                       help='Zachowaj kopie zapasowe oryginalnych plików')
    parser.add_argument('--quality', '-q', type=int, default=95,
                       help='Jakość JPEG 1-100 (domyślnie 95)')
    parser.add_argument('--formats', nargs='+', 
                       default=['png', 'jpg', 'jpeg', 'bmp', 'tiff', 'webp'],
                       help='Formaty do przetworzenia')
    parser.add_argument('--min-size', type=int, default=100,
                       help='Minimalna szerokość/wysokość do przetworzenia (px)')
    parser.add_argument('--dry-run', action='store_true',
                       help='Tylko pokaż co zostałoby przetworzone')
    
    args = parser.parse_args()
    
    project_path = Path(args.directory).resolve()
    
    if not project_path.exists():
        print(f"Błąd: Katalog {project_path} nie istnieje!")
        sys.exit(1)
    
    # Filtruj formaty według argumentów
    allowed_formats = {f'.{fmt.lower()}' for fmt in args.formats}
    global SUPPORTED_FORMATS
    SUPPORTED_FORMATS = SUPPORTED_FORMATS.intersection(allowed_formats)
    
    print(f"Skanowanie katalogu: {project_path}")
    print(f"Współczynnik skalowania: {args.scale}x ({1/args.scale:.1f}x mniejszy)")
    print(f"Obsługiwane formaty: {', '.join(sorted(SUPPORTED_FORMATS))}")
    print(f"Jakość JPEG: {args.quality}")
    print(f"Minimalna wielkość: {args.min_size}px")
    print(f"Zachowywanie kopii: {'Tak' if args.keep_backups else 'Nie'}")
    if args.dry_run:
        print("TRYB TESTOWY - żadne pliki nie zostaną zmienione")
    print("-" * 70)
    
    # Znajdź wszystkie pliki graficzne
    image_files = find_image_files(project_path)
    
    if not image_files:
        print("Nie znaleziono obsługiwanych plików graficznych w projekcie.")
        return
    
    # Filtruj pliki według minimalnego rozmiaru
    filtered_files = []
    for img_file in image_files:
        try:
            with Image.open(img_file) as img:
                width, height = img.size
                if width >= args.min_size or height >= args.min_size:
                    filtered_files.append(img_file)
                else:
                    print(f"⏭ Pominięto {img_file} (za mały: {width}x{height})")
        except Exception as e:
            print(f"⚠ Nie można odczytać {img_file}: {e}")
    
    image_files = filtered_files
    
    if not image_files:
        print("Nie znaleziono plików spełniających kryteria rozmiaru.")
        return
    
    print(f"Znaleziono {len(image_files)} plików do przetworzenia")
    print("-" * 70)
    
    if args.dry_run:
        for img_file in image_files:
            try:
                with Image.open(img_file) as img:
                    width, height = img.size
                    new_width = int(width * args.scale)
                    new_height = int(height * args.scale)
                    size = get_file_size(img_file)
                    print(f"🔍 {img_file}")
                    print(f"   {width}x{height} → {new_width}x{new_height} ({format_size(size)})")
            except Exception as e:
                print(f"⚠ {img_file}: {e}")
        return
    
    total_saved = 0
    processed = 0
    
    for img_file in image_files:
        try:
            saved_bytes = process_image_file(
                img_file, 
                scale_factor=args.scale,
                keep_backup=args.keep_backups,
                quality=args.quality
            )
            total_saved += saved_bytes
            processed += 1
        except KeyboardInterrupt:
            print("\nPrzerwano przez użytkownika.")
            break
        except Exception as e:
            print(f"✗ Błąd podczas przetwarzania {img_file}: {e}")
    
    print("-" * 70)
    print(f"Przetworzono: {processed}/{len(image_files)} plików")
    print(f"Łączne oszczędności: {format_size(total_saved)}")
    
    if total_saved > 0 and processed > 0:
        avg_savings = total_saved / processed
        print(f"Średnie oszczędności: {format_size(avg_savings)} na plik")
        
        # Oszacowanie wpływu na wydajność
        if args.scale <= 0.5:
            print(f"\n🎮 Wpływ na grę:")
            print(f"   • Szybsze wczytywanie tekstur")
            print(f"   • Mniejsze zużycie VRAM")
            print(f"   • Lepsza wydajność na słabszym sprzęcie")

if __name__ == "__main__":
    main()