import 'package:expanding_draggable_sheet/expanding_draggable_sheet.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: MyApp()));

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ExpandingDraggableSheet(
              initialChildSize: 0.6,
              minimumChildSize: 0.3,
              headerHeight: 30,
              headerChild: Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.grey,
                  ),
                ),
              ),
              appBarBuilder: (context) => AppBar(
                title: const Text('Expanding Draggable Sheet'),
                backgroundColor: Colors.white,
              ),
              child: Column(
                children: List.generate(
                  40,
                  (index) => ListTile(title: Text('Item #$index')),
                ),
              ),
            ),
          ),
          child: const Text('Open Sheet'),
        ),
      ),
    );
  }
}
