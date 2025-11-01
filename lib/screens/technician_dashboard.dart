import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  bool _loading = true;
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    try {
      if (userId != null) {
        final data = await Supabase.instance.client
            .from('tasks')
            .select('id,title,description,status,created_at')
            .eq('assigned_to', userId)
            .order('created_at', ascending: false)
            .maybeSingle();

        if (data == null) {
          _tasks = [];
        } else if (data is List) {
          _tasks = List<Map<String, dynamic>>.from(data);
        } else if (data is Map) {
          _tasks = [Map<String, dynamic>.from(data)];
        }
      } else {
        _tasks = [];
      }
    } catch (_) {
      _tasks = [
        {
          'id': 't1',
          'title': 'Perbaikan Router di Site A',
          'description': 'Ganti power supply, cek koneksi.',
          'status': 'open',
        },
        {
          'id': 't2',
          'title': 'Maintenance Switch di Gedung B',
          'description': 'Update firmware dan reboot.',
          'status': 'in_progress',
        },
      ];
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Teknisi 🛠️'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _tasks.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 60),
                  Center(child: Text('Tidak ada tugas saat ini')),
                ],
              )
            : ListView.builder(
                itemCount: _tasks.length,
                itemBuilder: (context, i) {
                  final t = _tasks[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(t['title'] ?? 'Untitled'),
                      subtitle: Text(t['description'] ?? ''),
                      trailing: Text(
                        (t['status'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Tambah Laporan'),
              content: const Text(
                'Fitur tambah laporan belum diimplementasikan.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          );
        },
        label: const Text('Tambah Laporan'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
