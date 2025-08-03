#!/usr/bin/env python3
"""
Skrypt do bezstratnej kompresji plików PNG w całym projekcie.
Używa PIL/Pillow do optymalizacji PNG oraz opcjonalnie pngquant dla lepszej kompresji.
"""

import os
import sys
from pathlib import Path
from PIL import Image, ImageFile
import subprocess
import shutil

# Umożliwia przetwarzanie uszkodzonych obrazów
ImageFile.LOAD_TRUNCATED_IMAGES = True

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

def is_pngquant_available():
    """Sprawdza czy pngquant jest dostępny w systemie."""
    return shutil.which('pngquant') is not None

def compress_png_pillow(input_path, output_path=None):
    """
    Kompresuje PNG używając PIL/Pillow z optymalnymi ustawieniami.
    """
    if output_path is None:
        output_path = input_path
    
    try:
        with Image.open(input_path) as img:
            # Konwertuj do RGB jeśli obraz jest w trybie P (paleta) bez przezroczystości
            if img.mode == 'P' and 'transparency' not in img.info:
                img = img.convert('RGB')
            
            # Zapisz z maksymalną optymalizacją
            save_kwargs = {
                'optimize': True,
                'format': 'PNG'
            }
            
            # Dla obrazów z przezroczystością zachowaj tryb RGBA
            if img.mode in ('RGBA', 'LA') or 'transparency' in img.info:
                save_kwargs['format'] = 'PNG'
            
            img.save(output_path, **save_kwargs)
        
        return True
    except Exception as e:
        print(f"Błąd podczas kompresji PIL {input_path}: {e}")
        return False

def compress_png_pngquant(input_path, output_path=None):
    """
    Kompresuje PNG używając pngquant (jeśli dostępny).
    """
    if output_path is None:
        output_path = input_path
    
    try:
        # Użyj pngquant z wysoką jakością (85-100)
        cmd = [
            'pngquant', 
            '--quality=85-100',
            '--force',
            '--output', output_path,
            input_path
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.returncode == 0
    except Exception as e:
        print(f"Błąd podczas kompresji pngquant {input_path}: {e}")
        return False

def compress_png_file(filepath):
    """
    Kompresuje pojedynczy plik PNG próbując różne metody.
    """
    original_size = get_file_size(filepath)
    backup_path = f"{filepath}.backup"
    
    # Utwórz kopię zapasową
    shutil.copy2(filepath, backup_path)
    
    best_size = original_size
    best_method = None
    temp_path = f"{filepath}.temp"
    
    try:
        if compress_png_pillow(filepath, temp_path):
            pillow_size = get_file_size(temp_path)
            if pillow_size < best_size:
                best_size = pillow_size
                best_method = "PIL/Pillow"
                shutil.copy2(temp_path, filepath)
        
        if is_pngquant_available():
            if compress_png_pngquant(backup_path, temp_path):
                pngquant_size = get_file_size(temp_path)
                if pngquant_size < best_size:
                    best_size = pngquant_size
                    best_method = "pngquant"
                    shutil.copy2(temp_path, filepath)
        
        final_size = get_file_size(filepath)
        
        if final_size < original_size:
            compression_ratio = ((original_size - final_size) / original_size) * 100
            print(f"✓ {filepath}")
            print(f"  {format_size(original_size)} → {format_size(final_size)} "
                  f"(-{compression_ratio:.1f}%) [{best_method}]")
            
            os.remove(backup_path)
            return original_size - final_size
        else:
            print(f"- {filepath} (brak poprawy)")
            shutil.move(backup_path, filepath)
            return 0
            
    except Exception as e:
        print(f"✗ Błąd podczas kompresji {filepath}: {e}")
        if os.path.exists(backup_path):
            shutil.move(backup_path, filepath)
        return 0
    
    finally:
        # Wyczyść pliki tymczasowe
        for temp_file in [temp_path, backup_path]:
            if os.path.exists(temp_file):
                try:
                    os.remove(temp_file)
                except:
                    pass

def find_png_files(directory):
    """
    Znajduje wszystkie pliki PNG w podanym katalogu i podkatalogach.
    """
    png_files = []
    for root, dirs, files in os.walk(directory):
        # Pomiń katalogi .git, node_modules, venv itp.
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['node_modules', 'venv', '__pycache__']]
        
        for file in files:
            if file.lower().endswith('.png'):
                png_files.append(os.path.join(root, file))
    
    return png_files

def main():
    # Katalog do skanowania (domyślnie bieżący katalog)
    project_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
    project_path = Path(project_dir).resolve()
    
    if not project_path.exists():
        print(f"Błąd: Katalog {project_path} nie istnieje!")
        sys.exit(1)
    
    print(f"Skanowanie katalogu: {project_path}")
    print(f"Pngquant dostępny: {'Tak' if is_pngquant_available() else 'Nie'}")
    print("-" * 60)
    
    # Znajdź wszystkie pliki PNG
    png_files = find_png_files(project_path)
    
    if not png_files:
        print("Nie znaleziono plików PNG w projekcie.")
        return
    
    print(f"Znaleziono {len(png_files)} plików PNG")
    print("-" * 60)
    
    total_saved = 0
    processed = 0
    
    for png_file in png_files:
        try:
            saved_bytes = compress_png_file(png_file)
            total_saved += saved_bytes
            processed += 1
        except KeyboardInterrupt:
            print("\nPrzerwano przez użytkownika.")
            break
        except Exception as e:
            print(f"✗ Błąd podczas przetwarzania {png_file}: {e}")
    
    print("-" * 60)
    print(f"Przetworzono: {processed}/{len(png_files)} plików")
    print(f"Łączne oszczędności: {format_size(total_saved)}")
    
    if total_saved > 0:
        print(f"Średnia kompresja: {format_size(total_saved // max(processed, 1))} na plik")

if __name__ == "__main__":
    main()