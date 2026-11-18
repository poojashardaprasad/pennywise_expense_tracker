import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const bg = Color(0xFF101714);
const panel = Color(0xFF1B2621);
const panel2 = Color(0xFF24332C);
const green = Color(0xFF69D39A);
const red = Color(0xFFFF7777);
const muted = Color(0xFF9AA9A1);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Db.instance.database;
  runApp(const MonefyApp());
}

class Txn {
  final int? id;
  final String title, category, type;
  final double amount;
  final DateTime date;
  Txn({this.id, required this.title, required this.category, required this.type,
    required this.amount, required this.date});
  Map<String, Object?> toMap() => {
    'id': id, 'title': title, 'category': category, 'type': type,
    'amount': amount, 'date': date.toIso8601String(),
  };
  factory Txn.fromMap(Map<String, Object?> m) => Txn(
    id: m['id'] as int, title: m['title'] as String,
    category: m['category'] as String, type: m['type'] as String,
    amount: (m['amount'] as num).toDouble(),
    date: DateTime.parse(m['date'] as String));
}

class Db {
  Db._();
  static final instance = Db._();
  Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(p.join(dir, 'monefy_local.db'), version: 1,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL, category TEXT NOT NULL,
          type TEXT NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL)''');
      });
    return _db!;
  }
  Future<List<Txn>> all() async {
    final rows = await (await database).query('transactions', orderBy: 'date DESC, id DESC');
    return rows.map(Txn.fromMap).toList();
  }
  Future<void> save(Txn t) async {
    final db = await database;
    if (t.id == null) {
      await db.insert('transactions', t.toMap()..remove('id'));
    } else {
      await db.update('transactions', t.toMap()..remove('id'), where: 'id=?', whereArgs: [t.id]);
    }
  }
  Future<void> delete(int id) async =>
    (await database).delete('transactions', where: 'id=?', whereArgs: [id]);
}

const categories = <String, IconData>{
  'Food': Icons.restaurant_rounded, 'Shopping': Icons.shopping_bag_rounded,
  'Transport': Icons.directions_bus_rounded, 'Bills': Icons.receipt_long_rounded,
  'Entertainment': Icons.movie_rounded, 'Health': Icons.favorite_rounded,
  'Home': Icons.home_rounded, 'Education': Icons.school_rounded,
  'Travel': Icons.flight_rounded, 'Other': Icons.more_horiz_rounded,
  'Salary': Icons.account_balance_wallet_rounded, 'Gift': Icons.card_giftcard_rounded,
  'Investment': Icons.trending_up_rounded,
};

class MonefyApp extends StatelessWidget {
  const MonefyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Pennywise',
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
      scaffoldBackgroundColor: bg, colorScheme: ColorScheme.fromSeed(
        seedColor: green, brightness: Brightness.dark, surface: panel),
      fontFamily: 'Roboto'),
    home: const HomePage());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  List<Txn> txns = [];
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  @override void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    final data = await Db.instance.all();
    if (mounted) setState(() => txns = data);
  }
  List<Txn> get monthTxns => txns.where((t) => t.date.year == month.year && t.date.month == month.month).toList();
  double get income => monthTxns.where((t)=>t.type=='income').fold(0,(s,t)=>s+t.amount);
  double get expense => monthTxns.where((t)=>t.type=='expense').fold(0,(s,t)=>s+t.amount);
  double get balance =>
    txns.where((t) => t.type == 'income')
        .fold<double>(0.0, (s, t) => s + t.amount) -
    txns.where((t) => t.type == 'expense')
        .fold<double>(0.0, (s, t) => s + t.amount);

  Future<void> add({Txn? edit}) async {
    await showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: panel, shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => TransactionSheet(existing: edit));
    await refresh();
  }
  @override Widget build(BuildContext context) {
    final pages = [
      dashboard(), historyPage(), statsPage()
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg, titleSpacing: 20,
        title: Row(children: [
          Container(width: 34,height: 34,decoration: BoxDecoration(
            color: green.withOpacity(.15),borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.account_balance_wallet_rounded,color: green,size: 20)),
          const SizedBox(width: 10),
          const Text('pennywise',style: TextStyle(fontWeight: FontWeight.w800,letterSpacing: -.5)),
        ]),
        actions: [IconButton(onPressed: () => setState(()=>month=DateTime.now()),
          icon: const Icon(Icons.calendar_month_rounded,color: muted))]),
      body: pages[tab],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: ()=>add(), backgroundColor: green, foregroundColor: bg,
        icon: const Icon(Icons.add_rounded), label: const Text('Add transaction',
          style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        backgroundColor: panel, indicatorColor: green.withOpacity(.16),
        selectedIndex: tab, onDestinationSelected: (v)=>setState(()=>tab=v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded),label:'Overview'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded),label:'Transactions'),
          NavigationDestination(icon: Icon(Icons.pie_chart_rounded),label:'Insights'),
        ]),
    );
  }

  Widget dashboard() {
    final recent = monthTxns.take(5).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(18,8,18,110), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('YOUR MONEY',style: TextStyle(color:muted,fontSize:11,
          letterSpacing:1.5,fontWeight:FontWeight.bold)),
        monthPicker(),
      ]),
      const SizedBox(height:14),
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(
        gradient: const LinearGradient(colors:[Color(0xFF263B30),Color(0xFF1B2922)],
          begin: Alignment.topLeft,end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(26), border: Border.all(color:green.withOpacity(.16))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('TOTAL BALANCE',style:TextStyle(color:muted,fontSize:11,
            letterSpacing:1.4,fontWeight:FontWeight.bold)),
          const SizedBox(height:7),
          Text(money.format(balance),style:const TextStyle(fontSize:34,
            fontWeight:FontWeight.w800,letterSpacing:-1.2)),
          const SizedBox(height:22),
          Row(children:[
            Expanded(child: amountTile('INCOME',income,green,Icons.south_west_rounded)),
            Container(width:1,height:42,color:Colors.white12,margin:const EdgeInsets.symmetric(horizontal:16)),
            Expanded(child: amountTile('EXPENSES',expense,red,Icons.north_east_rounded)),
          ])
        ])),
      const SizedBox(height:24),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        const Text('Spending breakdown',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
        Text(DateFormat('MMMM yyyy').format(month),style:const TextStyle(color:muted,fontSize:12)),
      ]),
      const SizedBox(height:14),
      Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(
        color:panel,borderRadius:BorderRadius.circular(24)),
        child: monthTxns.where((t)=>t.type=='expense').isEmpty
          ? const Padding(padding:EdgeInsets.all(25),child:Center(child:Text('Add an expense to see your breakdown',style:TextStyle(color:muted))))
          : Row(children:[
              SizedBox(width:132,height:132,child: CustomPaint(painter: DonutPainter(categoryTotals(monthTxns)))),
              const SizedBox(width:18),
              Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,
                children: categoryTotals(monthTxns).entries.take(4).map((e){
                  final total=categoryTotals(monthTxns).values.fold(0.0,(a,b)=>a+b);
                  final color=categoryColor(e.key);
                  return Padding(padding:const EdgeInsets.only(bottom:10),child:Row(children:[
                    Container(width:8,height:8,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),
                    const SizedBox(width:8),
                    Expanded(child:Text(e.key,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,color:muted))),
                    Text('${(e.value/total*100).round()}%',style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)),
                  ]));
                }).toList())),
            ])),
      const SizedBox(height:24),
      sectionHeader('Recent transactions', 'See all', ()=>setState(()=>tab=1)),
      const SizedBox(height:8),
      if(recent.isEmpty) emptyState('No transactions yet','Tap “Add transaction” to get started.')
      else ...recent.map((t)=>transactionTile(t)),
    ]);
  }

  Widget historyPage() => ListView(padding:const EdgeInsets.fromLTRB(18,8,18,110),children:[
    const Text('Transactions',style:TextStyle(fontSize:25,fontWeight:FontWeight.w800)),
    const SizedBox(height:5),const Text('Your latest money activity',style:TextStyle(color:muted)),
    const SizedBox(height:18),
    if(txns.isEmpty) emptyState('Nothing here yet','Your transactions will appear here.')
    else ...txns.map((t)=>transactionTile(t)),
  ]);

  Widget statsPage() {
    final totals=categoryTotals(monthTxns);
    return ListView(padding:const EdgeInsets.fromLTRB(18,8,18,110),children:[
      const Text('Insights',style:TextStyle(fontSize:25,fontWeight:FontWeight.w800)),
      const SizedBox(height:5),const Text('Understand your spending habits',style:TextStyle(color:muted)),
      const SizedBox(height:18),monthPicker(),
      const SizedBox(height:18),
      Row(children:[
        Expanded(child:smallStat('Income',income,green)),
        const SizedBox(width:12),Expanded(child:smallStat('Expenses',expense,red)),
      ]),
      const SizedBox(height:22),
      const Text('Expenses by category',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      if(totals.isEmpty) emptyState('No spending data','Add expenses to generate insights.')
      else ...totals.entries.map((e){
        final total=totals.values.fold(0.0,(a,b)=>a+b);
        final pct=e.value/total;
        return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(15),
          decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(17)),
          child:Column(children:[
            Row(children:[
              categoryIcon(e.key),const SizedBox(width:10),Expanded(child:Text(e.key,style:const TextStyle(fontWeight:FontWeight.w600))),
              Text(money.format(e.value),style:const TextStyle(fontWeight:FontWeight.bold)),
              const SizedBox(width:8),Text('${(pct*100).round()}%',style:const TextStyle(color:muted,fontSize:11)),
            ]),
            const SizedBox(height:12),
            ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(
              value:pct,minHeight:6,backgroundColor:panel2,color:categoryColor(e.key))),
          ]));
      }),
    ]);
  }

  Map<String,double> categoryTotals(List<Txn> list) {
    final map=<String,double>{};
    for(final t in list.where((t)=>t.type=='expense')) {
      map[t.category]=(map[t.category]??0)+t.amount;
    }
    final entries=map.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }
  Widget monthPicker()=>Container(decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(13)),
    child:Row(mainAxisSize:MainAxisSize.min,children:[
      IconButton(visualDensity:VisualDensity.compact,onPressed:()=>setState(()=>month=DateTime(month.year,month.month-1)),
        icon:const Icon(Icons.chevron_left_rounded,size:20)),
      Text(DateFormat('MMM yyyy').format(month),style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)),
      IconButton(visualDensity:VisualDensity.compact,onPressed:()=>setState(()=>month=DateTime(month.year,month.month+1)),
        icon:const Icon(Icons.chevron_right_rounded,size:20)),
    ]));
  Widget amountTile(String label,double amount,Color color,IconData icon)=>Row(children:[
    Container(width:32,height:32,decoration:BoxDecoration(color:color.withOpacity(.13),borderRadius:BorderRadius.circular(10)),
      child:Icon(icon,color:color,size:17)),const SizedBox(width:9),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:const TextStyle(color:muted,fontSize:9,letterSpacing:1,fontWeight:FontWeight.bold)),
      const SizedBox(height:3),Text(money.format(amount),style:TextStyle(color:color,fontWeight:FontWeight.bold,fontSize:16)),
    ]))
  ]);
  Widget smallStat(String label,double value,Color color)=>Container(padding:const EdgeInsets.all(17),
    decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(18)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:const TextStyle(color:muted,fontSize:12)),const SizedBox(height:8),
      Text(money.format(value),style:TextStyle(color:color,fontWeight:FontWeight.w800,fontSize:20)),
    ]));
  Widget sectionHeader(String title,String action,VoidCallback tap)=>Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
    Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
    TextButton(onPressed:tap,child:Text(action,style:const TextStyle(color:green))),
  ]);
  Widget emptyState(String title,String subtitle)=>Container(padding:const EdgeInsets.all(25),
    decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(20)),
    child:Column(children:[Icon(Icons.receipt_long_rounded,size:35,color:muted.withOpacity(.6)),
      const SizedBox(height:10),Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),
      const SizedBox(height:5),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:muted,fontSize:12))]));
  Widget categoryIcon(String category)=>Container(width:39,height:39,decoration:BoxDecoration(
    color:categoryColor(category).withOpacity(.13),borderRadius:BorderRadius.circular(13)),
    child:Icon(categories[category]??Icons.category_rounded,color:categoryColor(category),size:19));
  Widget transactionTile(Txn t)=>Dismissible(key:ValueKey(t.id),direction:DismissDirection.endToStart,
    background:Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.only(right:18),
      alignment:Alignment.centerRight,decoration:BoxDecoration(color:red.withOpacity(.18),borderRadius:BorderRadius.circular(17)),
      child:const Icon(Icons.delete_outline_rounded,color:red)),
    onDismissed:(_){Db.instance.delete(t.id!);refresh();},
    child:InkWell(onTap:()=>add(edit:t),borderRadius:BorderRadius.circular(17),
      child:Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(17)),
        child:Row(children:[
          categoryIcon(t.category),const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(t.title.isEmpty?t.category:t.title,style:const TextStyle(fontWeight:FontWeight.w600)),
            const SizedBox(height:4),Text('${t.category}  ·  ${DateFormat('d MMM').format(t.date)}',
              style:const TextStyle(color:muted,fontSize:11)),
          ])),
          Text('${t.type=='income'?'+':'−'}${money.format(t.amount)}',
            style:TextStyle(color:t.type=='income'?green:red,fontWeight:FontWeight.bold)),
        ]))));
}

Color categoryColor(String key) {
  const colors=[Color(0xFF69D39A),Color(0xFFFFB86B),Color(0xFF83B8FF),Color(0xFFE99AD0),
    Color(0xFFB8A1FF),Color(0xFFFF8585),Color(0xFF70D4D0),Color(0xFFE8D477)];
  return colors[categories.keys.toList().indexOf(key).clamp(0,colors.length-1)];
}

class DonutPainter extends CustomPainter {
  final Map<String,double> data;
  DonutPainter(this.data);
  @override void paint(Canvas canvas,Size size) {
    final total=data.values.fold(0.0,(a,b)=>a+b);
    if(total<=0)return;
    final rect=Rect.fromLTWH(5,5,size.width-10,size.height-10);
    final paint=Paint()..style=PaintingStyle.stroke..strokeWidth=17..strokeCap=StrokeCap.butt;
    var start=-1.5708;
    for(final e in data.entries) {
      final sweep=e.value/total*6.28318;
      paint.color=categoryColor(e.key);
      canvas.drawArc(rect,start,sweep,false,paint);
      start+=sweep;
    }
    final tp=TextPainter(text:TextSpan(text:'${data.length}',style:const TextStyle(
      color:Colors.white,fontSize:22,fontWeight:FontWeight.bold)),textDirection:ui.TextDirection.ltr)..layout();
    tp.paint(canvas,Offset((size.width-tp.width)/2,(size.height-tp.height)/2-5));
    final sub=TextPainter(text:const TextSpan(text:'categories',style:TextStyle(color:muted,fontSize:9)),textDirection:ui.TextDirection.ltr)..layout();
    sub.paint(canvas,Offset((size.width-sub.width)/2,(size.height+12)/2));
  }
  @override bool shouldRepaint(covariant DonutPainter old)=>old.data!=data;
}

class TransactionSheet extends StatefulWidget {
  final Txn? existing;
  const TransactionSheet({super.key,this.existing});
  @override State<TransactionSheet> createState()=>_TransactionSheetState();
}
class _TransactionSheetState extends State<TransactionSheet> {
  final amount=TextEditingController();
  final title=TextEditingController();
  String type='expense', category='Food';
  DateTime date=DateTime.now();
  bool saving=false;
  @override void initState(){super.initState();final t=widget.existing;if(t!=null){
    amount.text=t.amount.toStringAsFixed(t.amount.truncateToDouble()==t.amount?0:2);
    title.text=t.title;type=t.type;category=t.category;date=t.date;
  }}
  @override void dispose(){amount.dispose();title.dispose();super.dispose();}
  @override Widget build(BuildContext context) {
    final isExpense=type=='expense';
    final cats=categories.keys.where((k)=>isExpense
      ? !['Salary','Investment'].contains(k) : ['Salary','Gift','Investment','Other'].contains(k)).toList();
    return Padding(padding:EdgeInsets.fromLTRB(20,18,20,MediaQuery.of(context).viewInsets.bottom+22),
      child:SingleChildScrollView(child:Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
        Center(child:Container(width:42,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(5)))),
        const SizedBox(height:18),
        Text(widget.existing==null?'Add transaction':'Edit transaction',style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800)),
        const SizedBox(height:18),
        Container(padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(14)),
          child:Row(children:['expense','income'].map((v){
            final selected=type==v;
            return Expanded(child:GestureDetector(onTap:()=>setState(()=>{type=v,category=v=='income'?'Salary':'Food'}),
              child:Container(padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(
                color:selected?(v=='income'?green:red):Colors.transparent,borderRadius:BorderRadius.circular(11)),
                child:Text(v=='income'?'Income':'Expense',textAlign:TextAlign.center,
                  style:TextStyle(fontWeight:FontWeight.bold,color:selected?bg:muted)))));
          }).toList())),
        const SizedBox(height:17),
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          inputFormatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold),
          decoration:const InputDecoration(prefixText:'₹ ',hintText:'0.00',labelText:'Amount',
            filled:true,fillColor:bg,border:OutlineInputBorder(borderSide:BorderSide.none,borderRadius:BorderRadius.all(Radius.circular(14))))),
        const SizedBox(height:13),
        TextField(controller:title,decoration:const InputDecoration(labelText:'Note (optional)',
          filled:true,fillColor:bg,border:OutlineInputBorder(borderSide:BorderSide.none,borderRadius:BorderRadius.all(Radius.circular(14))))),
        const SizedBox(height:18),
        const Text('CATEGORY',style:TextStyle(color:muted,fontSize:11,letterSpacing:1.2,fontWeight:FontWeight.bold)),
        const SizedBox(height:10),
        Wrap(spacing:9,runSpacing:9,children:cats.map((c){
          final selected=category==c;
          return ChoiceChip(selected:selected,label:Row(mainAxisSize:MainAxisSize.min,children:[
            Icon(categories[c],size:15),const SizedBox(width:5),Text(c)]),
            onSelected:(_)=>setState(()=>category=c),
            selectedColor:green.withOpacity(.2),backgroundColor:bg,
            labelStyle:TextStyle(color:selected?green:Colors.white,fontSize:12),
            side:BorderSide(color:selected?green.withOpacity(.6):Colors.white10));
        }).toList()),
        const SizedBox(height:16),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.calendar_today_rounded,color:green),
          title:const Text('Date'),subtitle:Text(DateFormat('EEEE, d MMMM yyyy').format(date)),
          trailing:const Icon(Icons.edit_calendar_rounded,color:muted),
          onTap:()async{final d=await showDatePicker(context:context,initialDate:date,
            firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null)setState(()=>date=d);}),
        const SizedBox(height:12),
        SizedBox(width:double.infinity,height:52,child:FilledButton(
          style:FilledButton.styleFrom(backgroundColor:green,foregroundColor:bg),
          onPressed:saving?null:save,
          child:saving?const CircularProgressIndicator():Text(widget.existing==null?'Save transaction':'Update transaction',
            style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15)))),
      ])));
  }
  Future<void> save() async {
    final value=double.tryParse(amount.text.trim());
    if(value==null||value<=0){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter an amount greater than zero')));
      return;
    }
    setState(()=>saving=true);
    await Db.instance.save(Txn(id:widget.existing?.id,title:title.text.trim(),
      category:category,type:type,amount:value,date:date));
    if(mounted)Navigator.pop(context);
  }
}
