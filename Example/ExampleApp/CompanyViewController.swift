//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://www.jessesquires.com/JSQCoreDataKit
//
//
//  GitHub
//  https://github.com/jessesquires/JSQCoreDataKit
//
//
//  License
//  Copyright © 2015 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

import UIKit
import CoreData

import JSQCoreDataKit

import ExampleModel



class CompanyViewController: UITableViewController, NSFetchedResultsControllerDelegate {

    var stack: CoreDataStack!

    var frc: NSFetchedResultsController?
    
    var manager: CoreDataManager!

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        showSpinner()

        let model = CoreDataModel(name: modelName, bundle: modelBundle)
        let factory = CoreDataStackFactory(model: model)

        factory.createStackInBackground { (result: StackResult) -> Void in
            switch result {
            case .success(let s):
                self.stack = s
                self.manager = CoreDataManager(stack: self.stack)
                self.setupFRC()

            case .failure(let err):
                assertionFailure("Error creating stack: \(err)")
            }

            self.hideSpinner()
        }
    }


    // MARK: Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "segue" {
            let employeeVC = segue.destinationViewController as! EmployeeViewController
            let company = frc?.objectAtIndexPath(tableView.indexPathForSelectedRow!) as! Company
            //employeeVC.stack = self.stack
            employeeVC.manager = self.manager
            employeeVC.company = company
        }
    }


    // MARK: Helpers

    func fetchRequest() -> FetchRequest<Company> {
        let e = self.manager.entity(name: Company.entityName)
        let fetch = FetchRequest<Company>(entity: e)
        fetch.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return fetch
    }

    func setupFRC() {
        let request = fetchRequest()

        self.frc = NSFetchedResultsController(fetchRequest: request,
                                              managedObjectContext: self.manager.threadContext(),
                                              sectionNameKeyPath: nil,
                                              cacheName: nil)

        self.frc?.delegate = self

        fetchData()
    }

    func fetchData() {
        do {
            try self.frc?.performFetch()
            tableView.reloadData()
        } catch {
            assertionFailure("Failed to fetch: \(error)")
        }
    }

    private func showSpinner() {
        let spinner = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        spinner.startAnimating()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
    }

    private func hideSpinner() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .Add,
            target: self,
            action: #selector(didTapAddButton(_:)))
    }


    // MARK: Actions

    func didTapAddButton(sender: UIBarButtonItem) {
        self.manager.threadContext().performBlockAndWait {
            Company.newCompany(self.manager.threadContext())
            self.manager.saveContext()
        }
    }

    @IBAction func didTapTrashButton(sender: UIBarButtonItem) {
        let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        print("Hello")
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
            self.manager.threadContext().performBlockAndWait {
                let request = self.fetchRequest()
                
                do {
                    let objects = try self.manager.fetch(request: request)
                    print("objects to delete: \(objects.count)")
                    self.manager.deleteObjects(objects)
                    self.manager.saveContext()
                } catch {
                    print("Error deleting objects: \(error)")
                }
            }
        }
    }

    // MARK: Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.frc?.fetchedObjects?.count ?? 0
    }

    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let company = self.frc?.objectAtIndexPath(indexPath) as! Company
        cell.textLabel?.text = company.name
        cell.detailTextLabel?.text = "$\(company.profits).00"
        cell.accessoryType = .DisclosureIndicator
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Company"
    }


    // MARK: Table view delegate

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let obj = frc?.objectAtIndexPath(indexPath) as! Company
            self.manager.deleteObjects([obj])
            self.manager.saveContext()
        }
    }


    // MARK: Fetched results controller delegate

    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }

    func controller(
        controller: NSFetchedResultsController,
        didChangeSection sectionInfo: NSFetchedResultsSectionInfo,
                         atIndex sectionIndex: Int,
                                 forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Insert:
            tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Delete:
            tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        default:
            break
        }
    }

    func controller(
        controller: NSFetchedResultsController,
        didChangeObject anObject: AnyObject,
                        atIndexPath indexPath: NSIndexPath?,
                                    forChangeType type: NSFetchedResultsChangeType,
                                                  newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        case .Delete:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
        case .Update:
            configureCell(tableView.cellForRowAtIndexPath(indexPath!)!, atIndexPath: indexPath!)
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
    }
    
}
