import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/core/strings.dart';

/// bulmaca-motoru'nun kısa metinleri (33 dil). Sıra:
/// tr en de es fr ar fa he ur ru uk pl cs ro hu el it pt nl sv da nb fi ja ko zh hi bn id ms th vi fil
const Map<String, List<String>> kBulmacaTexts = {
  'undo': ['Geri al', 'Undo', 'Rückgängig', 'Deshacer', 'Annuler', 'تراجع', 'واگرد', 'בטל', 'واپس', 'Отменить', 'Скасувати', 'Cofnij', 'Zpět', 'Anulează', 'Visszavonás', 'Αναίρεση', 'Annulla', 'Desfazer', 'Ongedaan', 'Ångra', 'Fortryd', 'Angre', 'Kumoa', '戻す', '되돌리기', '撤销', 'वापस', 'ফেরত', 'Urungkan', 'Buat asal', 'เลิกทำ', 'Hoàn tác', 'I-undo'],
  'clear': ['Temizle', 'Clear', 'Leeren', 'Borrar', 'Effacer', 'مسح', 'پاک کن', 'נקה', 'صاف کریں', 'Очистить', 'Очистити', 'Wyczyść', 'Vymazat', 'Șterge', 'Törlés', 'Καθαρισμός', 'Pulisci', 'Limpar', 'Wissen', 'Rensa', 'Ryd', 'Tøm', 'Tyhjennä', 'クリア', '지우기', '清空', 'साफ़ करें', 'মুছুন', 'Bersihkan', 'Kosongkan', 'ล้าง', 'Xóa hết', 'I-clear'],
  'hint': ['İpucu', 'Hint', 'Tipp', 'Pista', 'Indice', 'تلميح', 'راهنما', 'רמז', 'اشارہ', 'Подсказка', 'Підказка', 'Podpowiedź', 'Nápověda', 'Indiciu', 'Tipp', 'Βοήθεια', 'Aiuto', 'Dica', 'Hint', 'Ledtråd', 'Hint', 'Hint', 'Vihje', 'ヒント', '힌트', '提示', 'संकेत', 'সংকেত', 'Petunjuk', 'Petunjuk', 'คำใบ้', 'Gợi ý', 'Pahiwatig'],
  'erase': ['Sil', 'Erase', 'Löschen', 'Borrar', 'Gommer', 'امسح', 'پاک', 'מחק', 'مٹائیں', 'Стереть', 'Стерти', 'Usuń', 'Smazat', 'Șterge', 'Radír', 'Σβήσιμο', 'Cancella', 'Apagar', 'Gum', 'Sudda', 'Slet', 'Slett', 'Pyyhi', '消す', '지우기', '擦除', 'मिटाएँ', 'মুছে দিন', 'Hapus', 'Padam', 'ลบ', 'Xóa', 'Burahin'],
  'notes': ['Not', 'Notes', 'Notizen', 'Notas', 'Notes', 'ملاحظات', 'یادداشت', 'הערות', 'نوٹس', 'Заметки', 'Нотатки', 'Notatki', 'Poznámky', 'Note', 'Jegyzet', 'Σημειώσεις', 'Note', 'Notas', 'Notities', 'Anteckningar', 'Noter', 'Notater', 'Muistiinpanot', 'メモ', '메모', '笔记', 'नोट्स', 'নোট', 'Catatan', 'Nota', 'โน้ต', 'Ghi chú', 'Tala'],
  'fill': ['Doldur', 'Fill', 'Füllen', 'Rellenar', 'Remplir', 'تعبئة', 'پر کردن', 'מלא', 'بھریں', 'Закрасить', 'Зафарбувати', 'Zamaluj', 'Vybarvit', 'Umple', 'Kitöltés', 'Γέμισμα', 'Riempi', 'Preencher', 'Vullen', 'Fyll', 'Udfyld', 'Fyll', 'Täytä', '塗る', '칠하기', '涂色', 'भरें', 'ভরাট', 'Isi', 'Isi', 'ระบาย', 'Tô', 'Punan'],
  'mark': ['İşaretle', 'Mark', 'Markieren', 'Marcar', 'Marquer', 'علامة', 'علامت', 'סמן', 'نشان', 'Отметить', 'Позначити', 'Zaznacz', 'Označit', 'Marchează', 'Jelölés', 'Σήμανση', 'Segna', 'Marcar', 'Markeren', 'Markera', 'Markér', 'Merk', 'Merkitse', '印', '표시', '标记', 'चिह्न', 'চিহ্ন', 'Tandai', 'Tanda', 'ทำเครื่องหมาย', 'Đánh dấu', 'Markahan'],
  'moves': ['Hamle', 'Moves', 'Züge', 'Movimientos', 'Coups', 'الحركات', 'حرکت‌ها', 'מהלכים', 'چالیں', 'Ходы', 'Ходи', 'Ruchy', 'Tahy', 'Mutări', 'Lépések', 'Κινήσεις', 'Mosse', 'Jogadas', 'Zetten', 'Drag', 'Træk', 'Trekk', 'Siirrot', '手数', '이동', '步数', 'चालें', 'চাল', 'Langkah', 'Langkah', 'จำนวนครั้ง', 'Nước đi', 'Galaw'],
  'restart': ['Baştan', 'Restart', 'Neu starten', 'Reiniciar', 'Recommencer', 'إعادة', 'از نو', 'התחל מחדש', 'دوبارہ', 'Заново', 'Заново', 'Od nowa', 'Znovu', 'Reîncepe', 'Újra', 'Από την αρχή', 'Ricomincia', 'Recomeçar', 'Opnieuw', 'Börja om', 'Forfra', 'Start på nytt', 'Alusta', 'やり直し', '다시 시작', '重来', 'फिर से', 'আবার', 'Ulangi', 'Mula semula', 'เริ่มใหม่', 'Chơi lại', 'Ulitin'],
  'target': ['Hedef', 'Target', 'Ziel', 'Meta', 'Objectif', 'الهدف', 'هدف', 'יעד', 'ہدف', 'Цель', 'Мета', 'Cel', 'Cíl', 'Țintă', 'Cél', 'Στόχος', 'Obiettivo', 'Meta', 'Doel', 'Mål', 'Mål', 'Mål', 'Tavoite', '目標', '목표', '目标', 'लक्ष्य', 'লক্ষ্য', 'Target', 'Sasaran', 'เป้าหมาย', 'Mục tiêu', 'Layunin'],
  'left': ['Kalan', 'Left', 'Übrig', 'Quedan', 'Restant', 'المتبقي', 'باقی', 'נותרו', 'باقی', 'Осталось', 'Залишилось', 'Zostało', 'Zbývá', 'Rămase', 'Maradt', 'Απομένουν', 'Rimasti', 'Restam', 'Over', 'Kvar', 'Tilbage', 'Igjen', 'Jäljellä', '残り', '남음', '剩余', 'बाकी', 'বাকি', 'Sisa', 'Baki', 'เหลือ', 'Còn lại', 'Natitira'],
  'tries': ['Deneme', 'Tries', 'Versuche', 'Intentos', 'Essais', 'المحاولات', 'تلاش', 'ניסיונות', 'کوششیں', 'Попытки', 'Спроби', 'Próby', 'Pokusy', 'Încercări', 'Próbák', 'Προσπάθειες', 'Tentativi', 'Tentativas', 'Pogingen', 'Försök', 'Forsøg', 'Forsøk', 'Yritykset', '試行', '시도', '尝试', 'प्रयास', 'চেষ্টা', 'Percobaan', 'Cubaan', 'ครั้งที่ลอง', 'Lượt thử', 'Subok'],
  'check': ['Dene', 'Check', 'Prüfen', 'Comprobar', 'Vérifier', 'تحقق', 'بررسی', 'בדוק', 'جانچیں', 'Проверить', 'Перевірити', 'Sprawdź', 'Zkontrolovat', 'Verifică', 'Ellenőrzés', 'Έλεγχος', 'Verifica', 'Verificar', 'Controleer', 'Kontrollera', 'Tjek', 'Sjekk', 'Tarkista', 'チェック', '확인', '检查', 'जाँचें', 'যাচাই', 'Periksa', 'Semak', 'ตรวจ', 'Kiểm tra', 'Suriin'],
};

/// Kısa metni dile göre seç.
String bt(String lang, String key) => Strings.pick(kBulmacaTexts[key]!, lang);

/// Bulmaca ailesinin ortak kullanım anlatımı (33 dil).
const kPuzzleHowTo = TutorialStep(Icons.touch_app, [
  'Hücrelere dokun ya da parmağını sürükle; rakamlı bulmacalarda alttaki düğmelerle rakam seç. Üstte geri al, baştan başla ve ipucu düğmeleri var. Bulmaca kurallara uyduğu anda çözülür.',
  'Tap cells or drag your finger; in number puzzles pick digits with the buttons below. Undo, restart and hint are at the top. The puzzle is solved as soon as every rule holds.',
  'Tippe Felder an oder ziehe mit dem Finger; bei Zahlenrätseln wählst du Ziffern unten. Oben: Rückgängig, Neustart und Tipp. Das Rätsel ist gelöst, sobald alle Regeln stimmen.',
  'Toca casillas o arrastra el dedo; en los de números elige cifras con los botones de abajo. Arriba: deshacer, reiniciar y pista. Se resuelve en cuanto se cumplen todas las reglas.',
  'Touchez les cases ou glissez le doigt ; pour les chiffres, choisissez-les avec les boutons du bas. En haut : annuler, recommencer, indice. Résolu dès que toutes les règles sont respectées.',
  'المس الخانات أو اسحب إصبعك، وفي ألغاز الأرقام اختر الرقم من الأزرار بالأسفل. في الأعلى تراجع وإعادة وتلميح. يُحل اللغز حالما تتحقق كل القواعد.',
  'خانه‌ها را لمس کن یا انگشتت را بکش؛ در پازل‌های عددی رقم را با دکمه‌های پایین انتخاب کن. واگرد، از نو و راهنما بالا هستند. با برقراری همهٔ قوانین پازل حل می‌شود.',
  'הקישו על תאים או גררו אצבע; בחידות מספרים בחרו ספרה בכפתורים למטה. למעלה: ביטול, התחלה מחדש ורמז. החידה נפתרת ברגע שכל החוקים מתקיימים.',
  'خانوں کو چھوئیں یا انگلی کھینچیں؛ عددی پہیلیوں میں نیچے کے بٹن سے ہندسہ چنیں۔ اوپر واپس، دوبارہ اور اشارہ۔ سب اصول پورے ہوتے ہی پہیلی حل ہو جاتی ہے۔',
  'Нажимайте на клетки или ведите пальцем; в числовых задачах выбирайте цифры кнопками внизу. Вверху — отмена, заново и подсказка. Головоломка решена, как только выполнены все правила.',
  'Торкайтеся клітинок або ведіть пальцем; у числових задачах обирайте цифри кнопками внизу. Угорі — скасування, заново й підказка. Головоломку розв’язано, щойно виконано всі правила.',
  'Dotykaj pól lub przeciągaj palcem; w łamigłówkach liczbowych wybieraj cyfry przyciskami na dole. U góry: cofnij, od nowa i podpowiedź. Rozwiązane, gdy wszystkie zasady są spełnione.',
  'Klepej na pole nebo táhni prstem; v číselných hlavolamech vybírej číslice tlačítky dole. Nahoře je zpět, znovu a nápověda. Vyřešeno, jakmile platí všechna pravidla.',
  'Atinge căsuțele sau trage cu degetul; la cele cu cifre alege cifra din butoanele de jos. Sus: anulare, reluare și indiciu. E rezolvat imediat ce toate regulile sunt respectate.',
  'Koppints a mezőkre vagy húzd az ujjad; számos rejtvényben lent választasz számjegyet. Fent: visszavonás, újrakezdés és tipp. Kész, amint minden szabály teljesül.',
  'Πάτα κελιά ή σύρε το δάχτυλο· στους αριθμητικούς γρίφους διάλεξε ψηφίο από τα κάτω κουμπιά. Πάνω: αναίρεση, από την αρχή, βοήθεια. Λύνεται μόλις ισχύουν όλοι οι κανόνες.',
  'Tocca le caselle o trascina il dito; nei rompicapi numerici scegli la cifra con i pulsanti in basso. In alto: annulla, ricomincia e aiuto. È risolto appena valgono tutte le regole.',
  'Toque nas casas ou arraste o dedo; nos de números escolha o dígito nos botões de baixo. No topo: desfazer, recomeçar e dica. Resolvido assim que todas as regras valem.',
  'Tik vakjes aan of sleep met je vinger; bij getallenpuzzels kies je cijfers onderaan. Bovenaan: ongedaan maken, opnieuw en hint. Opgelost zodra alle regels kloppen.',
  'Tryck på rutor eller dra med fingret; i sifferpussel väljer du siffror med knapparna nedtill. Överst: ångra, börja om och ledtråd. Löst så snart alla regler uppfylls.',
  'Tryk på felter eller træk med fingeren; i talopgaver vælger du cifre med knapperne forneden. Øverst: fortryd, forfra og hint. Løst, så snart alle regler er opfyldt.',
  'Trykk på ruter eller dra med fingeren; i tallgåter velger du sifre med knappene nederst. Øverst: angre, start på nytt og hint. Løst så snart alle regler er oppfylt.',
  'Napauta ruutuja tai vedä sormella; numeropulmissa valitse numero alapainikkeista. Ylhäällä kumoa, aloita alusta ja vihje. Ratkaistu heti, kun kaikki säännöt täyttyvät.',
  'マスをタップするか指でなぞります。数字パズルは下のボタンで数字を選択。上には戻す・やり直し・ヒント。すべてのルールを満たした瞬間に解けます。',
  '칸을 누르거나 손가락으로 끄세요. 숫자 퍼즐은 아래 버튼으로 숫자를 고릅니다. 위에는 되돌리기, 다시 시작, 힌트가 있어요. 모든 규칙이 맞는 순간 풀립니다.',
  '点按格子或用手指拖动；数字谜题用下方按钮选择数字。上方有撤销、重来和提示。所有规则满足即完成。',
  'खानों को छुएँ या उँगली खींचें; अंकों वाली पहेलियों में नीचे के बटनों से अंक चुनें। ऊपर वापस, फिर से और संकेत हैं। सारे नियम पूरे होते ही पहेली हल।',
  'ঘর ছুঁন বা আঙুল টানুন; সংখ্যার ধাঁধায় নিচের বোতাম থেকে অঙ্ক বাছুন। উপরে ফেরত, আবার ও সংকেত। সব নিয়ম মিললেই ধাঁধা সমাধান।',
  'Ketuk sel atau seret jari; pada teka-teki angka pilih angka dengan tombol di bawah. Di atas ada urungkan, ulangi, dan petunjuk. Selesai begitu semua aturan terpenuhi.',
  'Ketik petak atau seret jari; dalam teka-teki nombor pilih digit dengan butang di bawah. Di atas ada buat asal, mula semula dan petunjuk. Selesai sebaik semua peraturan dipenuhi.',
  'แตะช่องหรือลากนิ้ว ปริศนาตัวเลขเลือกเลขจากปุ่มด้านล่าง ด้านบนมีเลิกทำ เริ่มใหม่ และคำใบ้ ไขได้ทันทีที่ทุกกติกาครบ',
  'Chạm ô hoặc kéo ngón tay; câu đố số thì chọn chữ số bằng nút bên dưới. Phía trên có hoàn tác, chơi lại và gợi ý. Giải xong ngay khi mọi luật đều đúng.',
  'I-tap ang mga cell o i-drag ang daliri; sa mga puzzle ng numero pumili ng digit sa mga button sa ibaba. Nasa itaas ang undo, ulitin at pahiwatig. Lutas na kapag tama lahat ng patakaran.',
]);
