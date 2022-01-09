//
//  CartoonsTableViewController.swift
//  learningCloudKit
//
//  Created by Libranner Leonel Santos Espinal on 13/02/2020.
//  Copyright © 2020 Libranner Leonel Santos Espinal. All rights reserved.
//

import UIKit
import CoreData

final class CartoonsTableViewController: UITableViewController {
  private let apiURL = "https://rickandmortyapi.com/api/character/1,2"
  private let LOADED_KEY = "LOADED"
  private var cartoons = [Cartoon]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let isLoaded = UserDefaults.standard.bool(forKey: LOADED_KEY)
    if isLoaded {
      cartoons = fetchCartoons()
      self.tableView.reloadData()
    }
    else {
      getEpisodes { [weak self] (success) in
        guard let self = self else { return }

        UserDefaults.standard.set(true, forKey: self.LOADED_KEY)
        DispatchQueue.main.async {
          self.cartoons = self.fetchCartoons()
          self.tableView.reloadData()
        }
      }
    }
  }
  
  // MARK: - Table view data source
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return cartoons.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CartoonCell", for: indexPath)
    
    let cartoon = cartoons[indexPath.row]
    
    configureCell(cell, with: cartoon)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
    return "Eliminar"
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      deleteCartoon(cartoons[indexPath.row])
      cartoons.remove(at: indexPath.row)
      tableView.deleteRows(at: [indexPath], with: .fade)
    }
  }
  
  private func configureCell(_ cell: UITableViewCell, with cartoon: Cartoon) {
    cell.textLabel?.text = cartoon.name
  }
}

// MARK: - Cloud Service
private extension CartoonsTableViewController {
  func getEpisodes(completion: @escaping (_ success: Bool) -> Void) {
    guard
      let url = URL(string: apiURL) else {
        completion(false)
        return
      }

    let session = URLSession.shared
    let appDelegate = UIApplication.shared.delegate as? AppDelegate

    let task = session.dataTask(with: url) { (data, _, error) in
      guard let unWrappedData = data, error == nil else {
        completion(false)
        return
      }

      let context = appDelegate!.persistentContainer.viewContext
      context.mergePolicy = NSOverwriteMergePolicy
      context.automaticallyMergesChangesFromParent = true
      try? appDelegate?.persistentContainer.viewContext.setQueryGenerationFrom(.current)

      if let json = try? JSONSerialization.jsonObject(with: unWrappedData, options: []) as? [[String: Any]] {
        let cleanup = json.map {
          [
            "name": $0["name"] as? String ?? "",
            "species": $0["species"] as? String ?? "",
            "image": $0["image"] as? String ?? "",
            "status": $0["status"] as? String ?? ""
          ]
        }

        context.perform {
          let insertRequest = NSBatchInsertRequest(entity: Cartoon.entity(), objects: cleanup)
          do {
            let result =  try context.execute(insertRequest) as! NSBatchInsertResult
            debugPrint(result.result as! Bool)
          }
          catch {
            debugPrint(error)
          }

          try! context.save()
          completion(true)
        }
      }
      else {
        completion(false)
      }
    }

    task.resume()
  }
}

// MARK: - Core Data Logic
private extension CartoonsTableViewController {
  var currentContext: NSManagedObjectContext? {
    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    return appDelegate?.persistentContainer.viewContext
  }
  
  func fetchCartoons() -> [Cartoon] {
    var cartoons = [Cartoon]()
    let fetchRequest: NSFetchRequest<Cartoon> = Cartoon.fetchRequest()
    
    do {
      cartoons = try currentContext?.fetch(fetchRequest) ?? []
    }
    catch {
      print("Unexpected error: \(error)")
    }
    
    return cartoons
  }

  func deleteCartoon(_ cartoon: Cartoon) {
    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    guard let context = appDelegate?.persistentContainer.viewContext else {
      return
    }
    
    context.delete(cartoon)
    do {
      try context.save()
    }
    catch {
      print("Unexpected error")
    }
  }
}
